package LA::Utils;

use strict;
use Time::Local;

my %MONTHS = 
(
  'jan' => '01', 'feb' => '02', 'mar' => '03',
  'apr' => '04', 'may' => '05', 'jun' => '06',
  'jul' => '07', 'aug' => '08', 'sep' => '09',
  'oct' => '10', 'nov' => '11', 'dec' => '12'
);

sub get_months
{
  return %MONTHS;
}

sub get_mday
{
  my $mname = shift;
  return $MONTHS{lc($mname)};
}

sub get_months_regex
{
  my $months = '';
  foreach my $m (keys %MONTHS)
  {
    $months .= ucfirst(lc($m)) . '|';
  }
  $months =~ s/\|$//;
  return $months;
}

sub get_weeks_regex
{
  my @weeks = qw(sun mon tue wed thu fri sat);
  my $weeks = '';
  foreach my $w (@weeks)
  {
    $weeks .= ucfirst(lc($w)) . '|';
  }
  $weeks =~ s/\|$//;
  return $weeks;
}

# 
# Supported formats:
# Wed Nov 13 15:39:49 2020
# Nov 13 15:39:49 2020
# 11-13-2020 15:39:49 
# 
sub parse_seconds
{
  my $date_str = shift;

  my $week_regex  = get_weeks_regex();
  my $month_regex = get_months_regex();
  my ($month_str, $month, $day, $year, $hour, $min, $sec);
  if ($date_str =~ 
    /^(?:$week_regex)\s+($month_regex)\s+(\d{1,2})\s+(\d{2}):(\d{2}):(\d{2})\s+(\d{4})/)
  {
    ($month_str, $day, $hour, $min, $sec, $year) =
    ($date_str =~ 
    /^(?:$week_regex)\s+($month_regex)\s+(\d{1,2})\s+(\d{2}):(\d{2}):(\d{2})\s+(\d{4})/);
  }
  elsif ($date_str =~ 
        /^($month_regex)\s+(\d{1,2})\s+(\d{2}):(\d{2}):(\d{2})\s+(\d{4})/)
  {
    ($month_str, $day, $hour, $min, $sec, $year) =
    ($date_str =~ /^($month_regex)\s+(\d{1,2})\s+(\d{2}):(\d{2}):(\d{2})\s+(\d{4})/);
  }
  elsif ($date_str =~ m#^(\d{2})[/-](\d{2})[/-](\d{4})\s+(\d{2}):(\d{2}):(\d{2})#)
  {
    ($month, $day, $year, $hour, $min, $sec) =
    ($date_str =~ /^($month_regex)\s+(\d{2})\s+(\d{2}):(\d{2}):(\d{2})\s+(\d{4})/);
  }

  $month = $MONTHS{lc($month_str)} if $month_str;
  return '' unless $month;

  my $secs = timegm($sec, $min, $hour, $day, ($month-1), $year);
  return $secs;
}

1;
