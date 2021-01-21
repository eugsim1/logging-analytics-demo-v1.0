package LA::Parser::APIGateway;

use strict;
use Time::Local;
use LA::Utils;
use LA::Parser::Common;

our @ISA = qw( LA::Parser::Common );
our %FORMATS =
(
  'YEAR_MONTH_DAY_TIME' => 
  {
    regex  => qr/("time":\s*")(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})\.\d+Z(")/,
    fields => [qw(pre year month day hour min sec post)],
  },
);

sub new
{
  my ($class, %options) = @_;
  $class   = ref($class) || $class;
  my $self = \%options;

  bless($self, $class);
  $self->SUPER::new(%options, formats => \%FORMATS);
  return $self;
}

sub format_date
{
  my ($self, $secs) = @_;

  my $date = gmtime($secs);
  #
  # Sun Sep  9 01:46:40 2001
  #
  my ($mname, $day, $hour, $min, $sec, $year) = 
      ($date =~ /^\S+\s+(\S+)\s+(\d+)\s+(\d{2}):(\d{2}):(\d{2})\s+(\d{4})$/);
  my $month = LA::Utils::get_mday($mname);

  my $date_string = sprintf("%d-%02d-%02dT%02d:%02d:%02d.000Z", 
                          $year, $month, $day, $hour, $min, $sec);
  return $date_string;
}

1;
