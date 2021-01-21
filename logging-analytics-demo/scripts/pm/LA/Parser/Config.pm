package LA::Parser::Config;

use strict;
use FileHandle;
use Time::Local;

sub new
{
  my ($class, %defaults) = @_;
  my $self  = ref($class) || {};

  bless($self, $class);
  $self->{cname}    = 'config.properties';
  $self->{defaults} = \%defaults;
  $self->{config  } = {};
  return $self;
}

sub default
{
  my ($self, $name, $value) = @_;
  if ($value eq '')
  {
    return $self->{defaults}->{$name};
  }
  else
  {
    $self->{defaults}->{$name} = $value;
  }
}

sub items
{
  my $self = shift;
  return keys %{$self->{config}};
}

sub get
{
  my ($self, $root, $name) = @_;
  return $self->{config}->{$root}->{$name};
}

sub set
{
  my ($self, $root, $name, $value) = @_;
  $self->{config}->{$root}->{$name} = $value;
}

sub load_files_n_config
{
  my ($self, $dir) = @_;
  my (%files, %config);

  $dir = $self->default('toplevel_dir') unless $dir;
  $dir || die "ERROR: No top level directory provided for load_files_n_config()\n";

  $dir =~ s#/+#/#g;
  $dir =~ s#/$##;
  my $type = $self->default('filetype');
  if ($type)
  {
    $config{$dir}->{config} = {filetype => $type, config_file => 'cmdline'};
  }

  open(FIND, "find $dir -type f |") || die "Unable to list files under $dir: $!\n";
  my $cname = $self->{cname};
  while (my $file = <FIND>)
  {
    chomp($file);
    next if ($file =~ /\.(?:zip|gz)$/);
    if ($type eq '' && $file =~ m#/$cname$#)
    {
      my $prefix = $file;
      $prefix    =~ s#/+#/#g;
      $prefix    =~ s#(.*)/[^/]+#$1#;
      foreach my $p (keys %config)
      {
        if ($prefix =~ m#^$p/#)
        {
          die "ERROR: Found $cname at $p and $prefix.\n" .
              "Define only one at the top level.\n";
        }
      }
      $config{$prefix}->{config} = $self->load($file);
    }
    else
    {
      $files{$file} = 0;
    }
  }
  close(FIND);
  my @dirs = keys %config;
  die "ERROR: Unable to find a valid configuration file anywhere under $dir\n"
    if ($#dirs == -1);

  foreach my $d (@dirs)
  {
    $config{$d}->{files} = [];
    foreach my $f (keys %files)
    {
      next if $files{$f};
      next unless ($f =~ m#^$d/#);
      push(@{$config{$d}->{files}}, $f);
      $files{$f} = 1;
    }
  }

  my @missing = ();
  foreach my $f (keys %files)
  {
    push(@missing, $f) unless $files{$f};
  }

  if ($#missing == 0)
  {
    print "@missing does not have a $cname file defined:\n";
  }
  elsif ($#missing >= 0 && $#missing < 5)
  {
    print "The following files don't have a $cname file defined:\n";
    foreach my $m (@missing) { print " $m\n"; }
  }
  elsif ($#missing != -1)
  {
    print scalar(@missing) . " files don't have a $cname file defined.\n";
  }
  foreach my $d (keys %config)
  {
    my $count = @{$config{$d}->{files}};
    my $type  = $config{$d}->{config}->{filetype};
    my $file  = $config{$d}->{config}->{config_file};

    $self->set($d, 'files',       $config{$d}->{files});
    $self->set($d, 'filetype',    $type);
    $self->set($d, 'config_file', $file);
  }
}

sub load
{
  my ($self, $file) = @_;
  my $type;

  return {} unless -e $file;
  my $fh = FileHandle->new($file) || die "ERROR: Unable to open file $file: $!\n";
  my $config = {config_file => $file};
  while (my $line = $fh->getline())
  {
    next unless ($line =~ /^\s*data.parse.(\S+):\s*(.*)/);
    my $key         = $1;
    my $value       = $2;
    $value          =~ s/['"]//g;
    $value          =~ s/^\s+//;
    $value          =~ s/\s+$//;
    $config->{$key} = $value;

    if ($key eq 'record_lastdate')
    {
      # simple validation for epoch. 2001 and earlier are invalid.
      if ($value =~ /^\d+$/)
      {
        die "ERROR: $key in $file has an invalid date: $value\n"
          if ($value < 1000000000 || !gmtime($value));
      }
      my $secs = LA::Utils::parse_seconds($value);
      $secs || die "ERROR: $key in $file has an invalid date: $value\n";
      $config->{$key . '_secs'} = $secs;
    }
  }
  $fh->close();
  return $config;
}

1;
