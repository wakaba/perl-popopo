package Popopo::Entry;
use strict;
use warnings;
use List::Ish;

sub new ($;%) {
  my $class = shift;
  my $self = bless {@_}, $class;
  for (qw/msgstrs comments autocomments locations/) {
    if (not defined $self->{$_}) {
      $self->{$_} = List::Ish->new;
    } elsif (ref $self->{$_} eq 'ARRAY') {
      $self->{$_} = List::Ish->new([@{$self->{$_}}]);
    }
  }
  if (defined $self->{msgstr}) {
    $self->{msgstrs}->push ($self->{msgstr});
    delete $self->{msgstr};
  }
  $self->{$_} ||= {} for qw/flags tags/;
  return $self;
} # new

for my $attr (qw/msgid line column obsolete/) {
  eval qq{
    sub $attr (\$;\$) : lvalue {
      if (\@_ > 1) {
        \$_[0]->{$attr} = \$_[1];
      }

      \$_[0]->{$attr};
    } # $attr
    1;
  } or die $@;
}

for my $attr (qw/msgstrs comments autocomments locations/) {
  eval qq{
    sub $attr (\$) {
      return \$_[0]->{$attr};
    } # $attr
  };
}

sub msgstr ($;$) : lvalue {
  if (@_ > 1) {
    if ($_[0]->{msgstrs}->length > 0) {
      $_[0]->{msgstrs}->[0] = $_[1];
    } else {
      push @{$_[0]->{msgstrs}}, $_[1];
    }
  }
  $_[0]->{msgstrs}->[0];
} # msgstr

sub flags ($) {
  my $self = shift;
  return List::Ish->new ([keys %{$self->{flags}}]);
}

sub add_flag ($$) {
  my ($self, $flag) = @_;
  $self->{flags}->{$flag} = 1;
}

sub has_flag ($$) {
  my ($self, $flag) = @_;
  return $self->{flag};
}

sub tags ($) {
  my $self = shift;
  return List::Ish->new ([keys %{$self->{tags}}]);
}

sub add_tag ($$) {
  my ($self, $tag) = @_;
  $self->{tags}->{$tag} = 1;
}

sub has_tag ($$) {
  my ($self, $tag) = @_;
  return $self->{tag};
}

my $quote = sub ($) {
  my $s = shift;
  $s =~ s/\x5C/\x5C\x5C/g;
  $s =~ s/\x09/\x5Ct/g;
  $s =~ s/\x22/\x5C\x22/g;
  if ($s =~ /[\x0A\x0D]/) {
    $s =~ s/\x0D\x0A?|\x0A/\x5Cn\x22\x0A\x22/g;
    $s =~ s{((?:\x22\x5Cn\x22\x0A){2,})}{
      my $v = $1;
      $v =~ tr/\x22\x0A//d;
      "\x22$v\x22\x0A";
    }ge;
    $s =~ s/\x22\x0A\x22\z//;
  }
  if ($s =~ /\x0A/) {
    $s = "\x22\x0A\x22" . $s;
  }
  return "\x22" . $s . "\x22";
}; # $quote

my $quote_comment = sub ($$) {
  my $s = shift;
  my $prefix = shift;
  $s =~ s/\x0D\x0A?/\x0A/g;
  $s =~ s/\x0A/\x0A$prefix/g;
  if (length $s) {
    $s = $prefix . $s;
    $s .= "\x0A";
  }
  
  return $s;
}; # quote_comment

sub _stringify_comments ($) {
  my $self = shift;
    
  my $comment;

  $comment .= $quote_comment->($self->locations->join ("\x0A"), '#: ');
  $comment .= $quote_comment->($self->autocomments->join ("\x0A"), '#. ');
  $comment .= $quote_comment->($self->comments->join ("\x0A\x0A"), '# ');
  $comment .= $quote_comment->($self->flags->sort (sub { $_[0] cmp $_[1] })->join ("\x0A"), '#, ');
  $comment .= $quote_comment->($self->tags->sort (sub { $_[0] cmp $_[1] })->join ("\x0A"), '#?tag ');

  return $comment;
} # _stringify_comments

sub stringify ($) {
  my $self = shift;
  
  ## TODO: obsolete flag
  
  my $msgid = 'msgid ' . $quote->($self->msgid) . "\x0A";
  
  ## TODO: multiple msgstrs

  my $msgstr = 'msgstr ' . $quote->($self->msgstr) . "\x0A";
  
  my $r = $self->_stringify_comments . $msgid . $msgstr;
  return $r;
} # stringify

=head1 AUTHOR

Wakaba <wakaba@suikawiki.org>.

=head1 LICENSE

Copyright 2009 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
