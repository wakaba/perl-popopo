package Popopo::EntrySet;
use strict;
use warnings;
use List::Rubyish;

sub new ($;%) {
  my $class = shift;
  my $self = bless {@_}, $class;
  $self->{entries} = {};
  return $self;
} # new

sub entries ($) {
  return List::Rubyish->new([grep {$_} values %{$_[0]->{entries}}]);
} # entries

sub add_entry ($$) {
  my ($self, $new_entry) = @_;
  $self->{entries}->{$new_entry->msgid} = $new_entry;
} # add_entry

sub has_entry ($$) {
  return $_[1] eq '' ? $_[0]->{header} : $_[0]->{entries}->{$_[1]};
} # has_entry

for my $attr (qw/header footer/) {
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

sub get_or_create_header ($) {
  my $self = shift;
  return $self->header ||= do {
    require Popopo::Entry::Header;
    Popopo::Entry::Header->new (msgid => '', msgstrs => [''])->init_header
  };
} # get_or_create_header

sub stringify ($) {
  my $self = shift;

  my $r = '';

  my $header = $self->header;
  if ($header) {
    $r = $self->header->stringify;
  } else {
    require Popopo::Entry::Header;
    $r = Popopo::Entry::Header->new (msgid => '', msgstrs => [''])->init_header->stringify;
  }

  $r .= $self->entries->sort (sub { $_[0]->msgid cmp $_[1]->msgid })->map (sub { "\x0A" . $_->stringify })->join ('');

  my $footer = $self->footer;
  if ($footer) {
    $r .= "\x0A" . $footer->stringify;
  }

  return $r;
} # stringify

=head1 NAME

Popopo::EntrySet - A Class Representing PO Entries

=head1 DESCRIPTION

A C<Popopo::EntrySet> object represents a set of message catalog
entries contained in a PO (portable object) file.  An entry set has an
optional header entry, zero or more body entries, and an optional
footer entry, which are instances of C<Popopo::Entry::Header>,
C<Popopo::Entry>, and C<Popopo::Entry::Footer> respectively and are
accessible via C<header>, C<entries>, and C<footer> methods
respectively.

=head1 DEPENDENCY

This module requires Perl 5.8 or later.

This module requires L<List::Rubyish>, which is available from CPAN:

  # cpan
  cpan> install List::Rubyish

=head1 SEE ALSO

L<Popopo::Parser> - PO parser.

L<Popopo::Entry>, L<Popopo::Entry::Header>, L<Popopo::Entry::Footer> -
In-memory representations of PO entries

=head1 DOWNLOAD

The latest version of this module is available from
<http://suika.fam.cx/popopo/doc/readme>.

=head1 AUTHOR

Wakaba <w@suika.fam.cx>.

=head1 LICENSE

Copyright 2009 Wakaba <w@suika.fam.cx>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
