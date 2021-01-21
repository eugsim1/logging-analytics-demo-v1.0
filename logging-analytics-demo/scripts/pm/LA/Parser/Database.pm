package LA::Parser::Database;

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
  $self->verbose($options{verbose});
  return $self;
}

# Expects time in this format:
# Nov 12 10:39:45 2020
sub convert
{
  my ($self, $in_file, $in_fh, $out_fh, $offset) = @_;

  my $params = {out_fh => $out_fh, offset => $offset};
  $self->read_and_process($in_file, $in_fh, 'convert', $params);
}
  
sub get_last_record_time
{
  my ($self, $in_file, $in_fh, $prev_secs) = @_;

  my $params = { prev_secs => $prev_secs };
  $self->read_and_process($in_file, $in_fh, 'max_time', $params);
  return $params->{prev_secs};
}

sub read_and_process
{
  my ($self, $in_file, $in_fh, $action, $params) = @_;

  my $month_regex = LA::Utils::get_months_regex();
  my $line_no     = 0;
  while (my $line = $in_fh->getline())
  {
    $line_no++;
    my ($month_str, $day, $hour, $min, $sec, $year) =
    ($line =~ /^($month_regex)\s+(\d{2})\s+(\d{2}):(\d{2}):(\d{2})\s+(\d{4})/);
    if ($month_str eq '')
    {
      $params->{out_fh}->print($line) if ($action eq 'convert');
      next;
    }
    my $month = LA::Utils::get_mday($month_str);
    my $secs  = timegm($sec, $min, $hour, $day, ($month-1), $year);
    die "ERROR: Unable to extract times from $in_file, line $line_no\n" 
                unless $secs;

    if ($action eq 'convert')
    {
      my $new_date = gmtime($secs + $params->{offset});
      $new_date    =~ s/^...\s+//;  # Remove week day
      if ($self->verbose())
      {
        print "$secs + $params->{offset} = $new_date\n";
        print "$line$new_date\n";
      }
      $line =~ s/^($month_str\s+\d{2}\s+\d{2}:\d{2}:\d{2}\s+\d{4})/$new_date/;
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
  return $in_file;
}

1;
