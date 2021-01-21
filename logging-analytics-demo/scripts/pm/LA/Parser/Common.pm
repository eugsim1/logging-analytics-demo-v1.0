package LA::Parser::Common;

use strict;
use Time::Local;
use LA::Utils;

sub new
{
  my ($self, %options) = @_;

  $self->init(%options);
  $self->verbose($options{verbose});
}

sub init
{
  my ($self, %params) = @_;
  my $month_regex = LA::Utils::get_months_regex();
  my %formats = %{$params{formats}};
  foreach my $name (keys %formats)
  {
    my $r = $formats{$name}->{regex};
    $r    =~ s/<MONTH_NAME>/$month_regex/;
    $formats{$name}->{regex} = $r;
  }

  $self->{formats}     = \%formats;
  $self->{format_list} = [keys %formats];
}

sub verbose
{
  my ($self, $value) = @_;
  if ($value eq '')
  {
    return $self->{verbose};
  }
  else
  {
    $self->{verbose} = $value;
  }
}

sub matcher_names
{
  my ($self, @list) = @_;

  $self->{format_list} = \@list if $#list != -1;
  return @{$self->{format_list}};
}

sub match_line
{
  my ($self, $line) = @_;

  my @list = $self->matcher_names();
  my ($index, $name, @matched);
  for ($index=0; $index<@list; $index++)
  {
    $name    = $list[$index];
    @matched = ($line =~ /$self->{formats}->{$name}->{regex}/);
    print "$line $name - $self->{formats}->{$name}->{regex} - @matched\n"
                          if $self->verbose();
    last if ($#matched != -1);
  }
  return ($name, $index, @matched);
}

sub push_matcher
{
  my ($self, $current_index, $new_index) = @_;

  return if ($current_index == $new_index);

  my @list = $self->matcher_names();
  my $r    = splice(@list, $current_index, 1);
  splice(@list, $new_index, 0, $r);
  $self->matcher_names(@list);
}

sub assign_fields
{
  my ($self, $name, @matched) = @_;

  my @fnames = @{$self->{formats}->{$name}->{fields}};
  my %fields;
  for (my $i=0; $i<@fnames; $i++)
  {
    if ($fnames[$i] eq 'mname')
    {
      $fields{month} = LA::Utils::get_mday($matched[$i]);
    }
    else
    {
      $fields{$fnames[$i]} = $matched[$i];
    }
  }
  return %fields;
}

sub get_fields
{
  my ($self, $name, @matched) = @_;

  my %fields = $self->assign_fields($name, @matched);
  my $time   = $self->construct_time_from_fields(%fields);
  return ($time, %fields);
}

sub construct_time_from_fields
{
  my ($self, %fields) = @_;
  my $secs = timegm($fields{sec}, $fields{min}, $fields{hour}, 
                    $fields{day}, $fields{month}-1, $fields{year});
  return $secs;
}

sub replace
{
  my ($self, $line, $name, $secs, $offset, %fields) = @_;

  my $old_line = $line;
  my $regex    = $self->{formats}->{$name}->{regex};
  my $pre      = $fields{pre};
  my $post     = $fields{post};
  my $new_date = $self->format_date($secs + $offset);
  $line        =~ s/$regex/$pre$new_date$post/;

  if ($self->verbose())
  {
    print "$secs + $offset = $new_date\n";
    print "BEFORE: $old_line";
    print "AFTER: $line";
  }
  return $line;
}

sub format_date
{
  my ($self, $secs) = @_;

  my $date = gmtime($secs);
  $date    =~ s/^...\s+//; # Remove week day
  return $date;
}

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

  my $line_no = 0;
  while (my $line = $in_fh->getline())
  {
    $line_no++;
    my ($name, $index, @matched) = $self->match_line($line);
    die "ERROR: Unable to extract times from $in_file, line $line_no\n" 
          if ($#matched == -1);
    
    # Push the matched one to the top for faster processing the next time.
    $self->push_matcher($index, 0) if ($index != 0);

    my ($secs, %fields) = $self->get_fields($name, @matched);
    die "ERROR: Unable to extract times from $in_file, line $line_no\n" 
                unless $secs;

    if ($action eq 'convert')
    {
      $line = $self->replace($line, $name, $secs, $params->{offset}, %fields);
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
