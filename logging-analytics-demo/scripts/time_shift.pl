# 
# Copyright (c) Oracle America Inc. 2020
# All rights reserved
#
#
$| = 1;

BEGIN
{
  if ($0 =~ m#(.*)/#) { unshift(@INC, "$1/pm"); }
  else                { unshift(@INC, './pm');  }
}

use strict;
use Time::Local;
use FileHandle;
use Getopt::Long;

use LA::Parser::Config;

my %SUPPORTED_TYPES = 
(
  'oci vcn flow logs'    => 'LA::Parser::VCN',
  'oci api gateway logs' => 'LA::Parser::APIGateway',
  'database alert logs'  => 'LA::Parser::Database',
  'syslog logs'          => 'LA::Parser::Syslog',
  'cisco asa logs'       => 'LA::Parser::Syslog',
  'f5 logs'              => 'LA::Parser::Syslog',
  'juniper logs'         => 'LA::Parser::Syslog',
);

foreach my $type (keys %SUPPORTED_TYPES)
{
  my $module = $SUPPORTED_TYPES{$type};
  eval "use $module;"; die $@ if $@;
}

my %o;
main();

sub main
{
  my $stime = time();
  process();
  my $etime    = time();
  my $duration = $etime - $stime;
  $duration = ($duration > 60) ?  sprintf("%.0f", $duration/60) . ' minute' : 
              "$duration second";
  $duration .= 's' if ($duration > 1);
  print "Processed in $duration\n";
}

sub process
{
  get_options();
  print "Loading files ...\n";
  my $config = LA::Parser::Config->new(toplevel_dir => $o{input_dir},
                                       filetype     => $o{filetype},
                                       verbose      => $o{verbose});
  $config->load_files_n_config();
  init_parsers($config, verbose => $o{verbose});

  my $input_dir  = $o{input_dir};
  my $output_dir = $o{output_dir};
  $input_dir     =~ s#/+#/#g; $input_dir  =~ s#/$##;
  $output_dir    =~ s#/+#/#g; $output_dir =~ s#/$##g;
  my $params     = {input_dir            => $input_dir, 
                    output_dir           => $output_dir, 
                    offset               => $o{offset},
                    offset_type          => $o{offset_type},
                    record_lastdate_secs => $o{record_lastdate_secs}};

  my $action = $o{get_record_lastdate} ? 'get_record_lastdate' : 'convert';
  my $output = process_subdirs($action, $params, $config);
}

sub init_parsers
{
  my ($config, %parser_params) = @_;

  foreach my $dir ($config->items())
  {
    my $type    = $config->get($dir, 'filetype');
    my $file    = $config->get($dir, 'config_file');
    my $lc_type = lc($type);
    my $class   = $SUPPORTED_TYPES{$lc_type} 
          || die "ERROR: Invalid filetype $type in $file\n";
    my $parser = $class->new(%parser_params);
    $config->set($dir, parser => $parser);
  }
}

sub process_subdirs
{
  my ($action, $params, $config) = @_;

  my $output = {};
  my $offset = $params->{offset};
  foreach my $dir ($config->items())
  {
    my $ref   = $config->get($dir, 'files');
    my $type  = $config->get($dir, 'filetype');
    my $count = @$ref;

    print "Processing $dir ($action - $count file(s)) - $type\n";
    if ($action eq 'get_record_lastdate')
    {
      my $secs = get_time_for_dir($dir, $config, $ref);
      print "   Current Time in the file: " . gmtime($secs) . "\n";
      $output->{$dir} = $secs;
    }
    elsif ($action eq 'convert')
    {
      $params->{offset} = $offset;
      $params->{offset} = get_offset($params, $config, $dir);
      convert_dir($dir, $params, $config, $ref);
    }
  }
  return $output;
}

sub get_time_for_dir
{
  my ($dir, $config, $files) = @_;

  my $parser = $config->get($dir, 'parser');
  my $secs   = '';
  foreach my $file (@$files)
  {
    my $fh = FileHandle->new($file);
    $fh || die "ERROR: Unable to open $file: $!\n";

    $secs = $parser->get_last_record_time($file, $fh, $secs);
    print scalar gmtime($secs) . " ($secs)\n" if $o{verbose};
    $fh->close();
  }
  return $secs;
}

sub get_offset
{
  my ($params, $config, $dir) = @_;
  
  return $params->{offset} if ($params->{offset_type} ne 'shift_to');

  # Global last date in command line, or configuration specific to this directory
  my $file_time = $params->{record_lastdate_secs} || 
                  $config->get($dir, 'record_lastdate_secs');

  # No value in command line, and no configuration. Read all the records
  # and compute the last timestamp.
  if (!$file_time)
  {
    my $files  = $config->get($dir, 'files');
    $file_time = get_time_for_dir($dir, $config, $files);
    $file_time || die "ERROR: Unable to get last record time for $dir\n";
  }

  my $shift_to = time() + $params->{offset};
  my $offset   = $shift_to - $file_time;
  print "   Current Time in the file: " . gmtime($file_time) . "\n" .
        "   Shifting last date to " . gmtime($shift_to) . 
        " by adding $offset seconds.\n" .
        "   $file_time + $offset = " . gmtime($file_time + $offset) . "\n\n";
  $config->set($dir, 'record_lastdate_secs', $offset);
  return $offset;
}

sub convert_dir
{
  my ($dir, $params, $config, $files) = @_;

  my $input_dir  = $params->{input_dir};
  my $output_dir = $params->{output_dir};
  my $offset     = $params->{offset};
  my $parser     = $config->get($dir, 'parser');
  foreach my $in_file (@$files)
  {
    my $path     = $in_file;
    $path        =~ s#^$input_dir/#$output_dir/#;
    $path        =~ s#^(.*?)/([^/]+)$#$1/#;
    my $file     = $2;
    my $out_file = $path . $parser->get_outfile($file, $offset);
    print "  $in_file -> $out_file\n" if $o{verbose};

    if (!-d $path)
    {
      system("mkdir -p $path") 
          && die "ERROR: Unable to create output directory $path\n";
    }
    convert_one_file($in_file, $out_file, $offset, $parser);
  }
}

sub convert_one_file
{
  my ($in_file, $out_file, $offset, $parser) = @_;

  die "ERROR: Target file $out_file already exists. Please remove and try again\n" 
      if -e $out_file;

  my $in_fh = FileHandle->new($in_file);
  $in_fh || die "ERROR: Unable to open $in_file: $!\n";

  my $out_fh = FileHandle->new(">$out_file");
  $out_fh || die "ERROR: Unable to open $out_file: $!\n";

  $parser->convert($in_file, $in_fh, $out_fh, $offset);
  $in_fh->close();
  $out_fh->close();
}

sub get_options
{
  GetOptions(\%o,
             'help',
             'verbose',
             'filetype=s',
             'input_dir=s',
             'output_dir=s',
             'offset=s',
             'shift_to=s',
             'record_lastdate=s',
             'get_record_lastdate');

  usage() if exists $o{help};
  $o{input_dir}  || usage('-input_dir is mandatory');
  $o{output_dir} || usage('-output_dir is mandatory') 
                              unless $o{get_record_lastdate};
  
  my $input_dir  = $o{input_dir};
  my $output_dir = $o{output_dir};
  $o{filetype}   = lc($o{filetype});
  $o{verbose}    = exists($o{verbose}) ? 1 : 0;

  my $types    = join(', ', sort keys %SUPPORTED_TYPES);
  if ($o{filetype})
  {
    usage("Invalid -filetype $o{filetype}. Supported Types are: $types\n")
        unless exists $SUPPORTED_TYPES{$o{filetype}};
  }
  die "ERROR: Input Directory $input_dir does not exist.\n" unless-d $input_dir;
  return if exists $o{get_record_lastdate};

  die "ERROR: Output Directory $output_dir does not exist.\n" unless-d $output_dir;

  if (!$o{offset} && !$o{shift_to})
  {
    usage('You must specify one of -offset or -shift_to options.');
  }
  elsif ($o{offset} && $o{shift_to})
  {
    usage('You must specify only one of -offset or -shift_to options.');
  }
  my $type   = $o{offset} ? 'offset' : 'shift_to';
  my $offset = $o{$type};
  $offset    = '-1s' if ($type eq 'shift_to' && $offset =~ /^today$/i);
  $offset    =~ /^([-|+]?\d+)(\D+)/;
  $offset    = $1;
  my $unit   = lc($2);
  $offset    =~ s/^\+//;
  usage("Invalid -$type $o{$type}") unless ($offset =~ /^-?\d+$/);

  if ($unit =~ /^s|sec|second|seconds$/)
  {
    $offset *= 1;
  }
  elsif ($unit =~ /^min|minutes?$/)
  {
    $offset *= 60;
  }
  elsif ($unit =~ /^h|hr|hours?$/)
  {
    $offset *= 60 * 60;
  }
  elsif ($unit =~ /^d|days?$/)
  {
    $offset *= 24 * 60 * 60;
  }
  elsif ($unit =~ /^m|months?$/)
  {
    $offset *= 30 * 24 * 60 * 60;
  }
  elsif ($unit =~ /^y|years?$/)
  {
    $offset *= 365 * 24 * 60 * 60;
  }
  else
  {
    usage("Invalid unit $unit in -$type $o{$type}");
  }

  if ($o{record_lastdate})
  {
    my $secs = LA::Utils::parse_seconds($o{record_lastdate});
    $secs || usage("Invalid value $o{record_lastdate} for -record_lastdate");
    $o{record_lastdate_secs} = $secs;
  }

  $o{offset}      = $offset;
  $o{offset_type} = $type;
}

sub usage
{
  my $error = shift;

  my @types = sort keys %SUPPORTED_TYPES;
  my $usage =<<END_OF_USAGE;
  Usage: $0 <options>
  -filetype:  Type of the File to be processed. Following Types are supported:
              @types
  -input_dir: Top level input directory. Traverses one level of sub-directories.
  -output_dir: Output directory. Creates the sub-directories found under input_dir
  -offset:    Add an offset to each record timestamp. Following are some examples:
     -offset=10min - Add 10 minutes to each entry
     -offset=-5min - Set each entry back by 5 minutes
     -offset=2h    - Add 2 hours to each entry
     -offset=90d   - Add 90 days to each entry
     -offset=3m    - Add 3 months to each entry. Same as 90d
  -shift_to: Auto-detect an offset to shift the last record to the specified time.
    -shift_to=today  - Add an appropriate offset to bring the last date in the 
                       record to current time. All the other records would be 
                       shifted accordingly.
    -shift_to=-24h   - Same as above, except the last record would be shifted to
                       yesterday.
  -record_lastdate: shift_to first sorts the records to identify the last
  timestamp. Then an offset is computed. Supply the last record date explicitly to
  avoid this computation.
    Example: 
      -record_lastdate: Wed Nov 13 15:39:49 2020
      -record_lastdate: Nov 13 15:39:49 2020
      -record_lastdate: 11-13-2020 15:39:49 
  -get_record_lastdate - Print the timestamp for the latest record.
END_OF_USAGE

  my $message = "ERROR: $error\n" if $error;
  $message   .= "$usage\n";
  die $message;
}

