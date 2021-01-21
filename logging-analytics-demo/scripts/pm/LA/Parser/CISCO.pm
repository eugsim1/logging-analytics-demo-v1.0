package LA::Parser::CISCO;

use strict;

our @ISA = qw( LA::Parser::Common );
our %FORMATS =
(
  'MONTH_DAY_YEAR_TIME' => 
  {
    regex => qr/^(<MONTH_NAME>)\s+(\d{2})\s+(\d{4})\s+(\d{2}):(\d{2}):(\d{2})(:)/,
    fields => [qw(mname day year hour min sec post)],
  }
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

1;
