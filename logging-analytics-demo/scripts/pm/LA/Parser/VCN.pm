package LA::Parser::VCN;

use strict;
use Time::Local;
use LA::Utils;
use LA::Parser::Common;

our @ISA = qw( LA::Parser::Common );

sub new
{
  my ($class, %options) = @_;
  $class   = ref($class) || $class;
  my $self = \%options;

  bless($self, $class);
  $self->SUPER::verbose($options{verbose});
  return $self;
}

sub get_last_record_time
{
  my ($self, $in_file, $in_fh, $prev_secs) = @_;

  my $params = { prev_secs => $prev_secs };
  $self->read_and_process($in_file, $in_fh, 'max_time', $params);
  return $params->{prev_secs};
}

sub convert
{
  my ($self, $in_file, $in_fh, $out_fh, $offset) = @_;

  my $params = {out_fh => $out_fh, offset => $offset};
  $self->read_and_process($in_file, $in_fh, 'convert', $params);
}
  
sub read_and_process
{
  my ($self, $in_file, $in_fh, $action, $params) = @_;

  my $line_no     = 0;
  while (my $line = $in_fh->getline())
  {
    $line_no++;
  # 2 129.146.12.201 10.0.0.7 443 47996 6 14 5426 1571362180 1571362180 ACCEPT OK
    my ($secs, $end_secs) = (split(/\s/, $line))[8, 9];

    die "ERROR: Unable to extract times from $in_file, line #$line_no\n" 
      unless ($secs && $end_secs);

    if ($action eq 'convert')
    {
      my $new_secs     = $secs     + $params->{offset};
      my $new_end_secs = $end_secs + $params->{offset};
      $line =~ s/ $secs $end_secs / $new_secs $new_end_secs /;
      if ($self->verbose())
      {
        print "$secs [" . gmtime($secs) . "] + $params->{offset} = " .
              "$new_secs [" . gmtime($new_secs) . "]\n";
      }
      $params->{out_fh}->print($line);
    }
    elsif ($action eq 'max_time')
    {
      $params->{prev_secs} = $secs 
        if (!$params->{prev_secs} or $secs > $params->{prev_secs});
    }
  }
}

sub get_outfile
{
  my ($self, $in_file, $offset) = @_;

  $in_file =~ m#([^/]+)Z#;
  my $name = $1;
  die "ERROR: Unable to extract time part from file name: $in_file\n" unless $name;
  my ($year, $month, $day, $hour, $min) 
    = ($name =~ /(\d+)-(\d+)-(\d+)T(\d+):(\d+)/);

  die "ERROR: Unable to extract time details from $in_file\n" unless $year;
  my $secs     = timegm(0, $min, $hour, $day, ($month-1), $year);
  my $new_secs = $secs + $offset;
  my $gmtime   =  gmtime($new_secs);

  my $time;
  ($day, $month, $year, $time) = (split('\s+', $gmtime))[2, 1, 4, 3];
  ($hour, $min)   = split(/:/, $time);
  my $month_num   = LA::Utils::get_mday($month);
  my $date_string = sprintf("%04d-%02d-%02dT%02d:%02d", $year, $month_num, $day,
                                                          $hour, $min);
  $in_file =~ s/${name}Z/${date_string}Z/;
  return $in_file;
}
1;
