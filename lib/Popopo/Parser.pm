package Popopo::Parser;
use strict;
use warnings;
use Popopo::EntrySet;
use Popopo::Entry;
use Popopo::Entry::Header;
use Popopo::Entry::Footer;

sub new ($;%) {
  my $class = shift;
  my $self = bless {@_}, $class;
  $self->{onerror} ||= sub {
    my %opt = @_;
    warn join ',', @opt{qw/line column type/};
  }; # onerror
  $self->{level} ||= {
    po_fatal => 'm',
    warning => 'w',
  };
  return $self;
} # new

## TODO: charset support

sub _next_token ($) {
  my $self = shift;
 
  my $s = $self->{s};

  X: {
    if ($$s =~ /\G([\x09\x0A\x0C\x0D\x20]+)/gc) { ## TODO: What is space?
      my $v = $1;
      if ($v =~ /[\x0D\x0A]/) {
        $self->{l}++ while $v =~ s/^[^\x0D\x0A]*(?:\x0A|\x0D\x0A?)//;
        $self->{c} = 1 + length $v;
        delete $self->{obsolete};
      } else {
        $self->{c} += length $v;
      }
      redo X;
    } elsif ($$s =~ /\G([^\x09\x0A\x0C\x0D\x20\x22\x23]+)/gc) {
      $self->{c} += length $1;
      return {type => 'token', value => $1,
              obsolete => $self->{obsolete},
              line => $self->{l}, column => $self->{c} - length $1};
    } elsif ($$s =~ /\G\x22((?>[^\x0A\x0C\x0D\x22\x5C]+|\x5C(?>[^\x0D]|\x0D\x0A?))*)(\x22?)/gc) {
      my $t = $1;
      my $has_terminator = $2;

      my $l = $self->{l};
      my $c = $self->{c};
      $self->{c}++;
      
      my $u = '';
      
      while (length $t) {
        if ($t =~ s/^([^\x5C]+)//) {
          $u .= $1;
          $self->{c} += length $1;
        }
          
        if ($t =~ s/^\\([ntrf\x5C\x22])//) {
          $u .= {
            n => "\x0A",
            t => "\x09",
            r => "\x0D",
            f => "\x0C",
            "\x5C" => "\x5C",
            "\x22" => "\x22",
          }->{$1};
          $self->{c} += 2;
          next;
        }

        ## TODO: other control sequences

        if ($t =~ s/^\\([0-7]{1,3})//) {
          $u .= pack 'C', oct $1;
          $self->{c} += 1 + length $1;
          next;
        }

        if ($t =~ s/^\\(?:\x0A|\x0D\x0A?)//) {
          $self->{onerror}->(type => 'eol in string',
                             level => $self->{level}->{po_fatal},
                             line => $self->{l}, column => $self->{c});
          $self->{l}++;
          $self->{c} = 1;
          next;
        }

        if ($t =~ s/^\\(.)//s) {
          $self->{onerror}->(type => 'invalid control sequence',
                             level => $self->{level}->{po_fatal},
                             line => $self->{l}, column => $self->{c});
          $u .= $1;
          $self->{c} += 2;
        }
      }

      unless ($has_terminator) {
        $self->{onerror}->(type => 'string not closed',
                           level => $self->{level}->{po_fatal},
                           line => $self->{l}, column => $self->{c});
        $self->{c}++;
      }

      return {type => 'string', value => $u,
              obsolete => $self->{obsolete},
              line => $l, column => $c};
    #} elsif ($$s =~ /\G\x23\|/gc) {
    #  $self->{c} += 2;
    #  return {type => 'old',
    #          line => $self->{l}, column => $self->{c} - 2};
    } elsif ($$s =~ /\G\x23~/gc) {
      $self->{c} += 2;
      $self->{obsolete} = 1;
      redo X;
    } elsif ($$s =~ /\G\x23([^\x0D\x0A]*)/gc) {
      $self->{c} += 1 + length $1;
      return {type => 'directive', value => $1,
              line => $self->{l}, column => $self->{c} - 1 - length $1};
    } elsif ($$s =~ /\G(.)/gcs) { ## Should not match anything
      return {type => 'token', value => $1,
              line => $self->{l}, column => $self->{c}++}
    } else {
      return {type => 'eof',
              line => $self->{l}, column => $self->{c}};
    }
  } # X
} # _next_token

sub parse_string ($$) {
  my $self = shift;

  $self->{s} = \($_[0]);
  pos ${$self->{s}} = 0;
  $self->{l} = 1;
  $self->{c} = 1;

  my $entry_set = Popopo::EntrySet->new;
  my $entry;

  my $token;

  my $create_entry = sub ($) {
    my $token = shift;
    $entry = Popopo::Entry->new (msgid => '', msgstr => '');
    $entry->line = $token->{line};
    $entry->column = $token->{column};
  }; # $create_entry

  my $save_entry = sub ($) {
    my $entry = shift;
    if ($entry_set->has_entry ($entry->msgid)) {
      $self->{onerror}->(type => 'duplicate msgid',
                         level => $self->{level}->{po_fatal},
                         line => $entry->line, column => $entry->column,
                         value => $entry->msgid);
    } elsif ($entry->msgid eq '') {
      if ($entry_set->entries->length) {
        $self->{onerror}->(type => 'header not first entry',
                           level => $self->{level}->{warning},
                           line => $entry->line, column => $entry->column);
      }

      bless $entry, 'Popopo::Entry::Header';
      $entry->init_header;
      
      $entry_set->header ($entry);
    } else {
      ## TODO: move to Checker
      if ($entry->msgid =~ /^\x0A/ != $entry->msgstr =~ /^\x0A/) {
        $self->{onerror}->(type => 'no newline prefix',
                           level => $self->{level}->{po_fatal},
                           line => $entry->line, column => $entry->column);
      } elsif ($entry->msgid =~ /\x0A\z/ != $entry->msgstr =~ /\x0A\z/) {
        $self->{onerror}->(type => 'no newline suffix',
                           level => $self->{level}->{po_fatal},
                           line => $entry->line, column => $entry->column);
      }

      $entry_set->add_entry ($entry);
    }
    undef $entry;
  }; # $save_entry

  my $check_obsolete = sub () {
    if ($token->{obsolete}) {
      unless ($entry->obsolete) {
        $self->{onerror}->(type => 'inconsistent tilde',
                           level => $self->{level}->{po_fatal},
                           token => $token);
        #$entry->obsolete = 1;
      }
    } else {
      if ($entry->obsolete) {
        $self->{onerror}->(type => 'inconsistent tilde',
                           level => $self->{level}->{po_fatal},
                           token => $token);
        $self->{obsolete} = 1;
      }
    }
  }; # $check_obsolete

  my $state = 'before entry';
  my $comment;
  while ($token = $self->_next_token) {
    if ($state eq 'before entry') {
      if ($token->{type} eq 'eof') {
        last;
      } else {
        $save_entry->($entry) if defined $entry;
        $create_entry->($token);
        $state = 'before msgid';
        redo;
      }
    } elsif ($state eq 'before msgid') {
      if ($token->{type} eq 'token' and $token->{value} eq 'msgid') {
        $entry->obsolete = 1 if $token->{obsolete};
        $state = 'before msgid literal';
      } elsif ($token->{type} eq 'directive') {
        my $value = $token->{value};
        if ($value =~ s/^,[\x09\x0A\x0C\x0D\x20]*//) {
          ## TODO: warning for "#,xxx" (no space after ",")
          $value =~ s/[\x09\x0A\x0C\x0D\x20]+\z//;
          $entry->add_flag ($_)
              for grep {length}
                  split /[\x09\x0A\x0C\x0D\x20]*,[\x09\x0A\x0C\x0D\x20]*/,
                  $value;
          #$state = 'before msgid';
        } elsif ($value =~ s/^://) {
          ## TODO: warning for "#:xxx" (no space after ":")
          $entry->locations->push ($_)
              for grep {length}
                  split /[\x09\x0A\x0C\x0D\x20]+/,
                  $value;
          #$state = 'before msgid';
        } elsif ($value =~ s/^\.//) {
          ## TODO: warning for "#.xxx" (no space after ".")
          ## TODO: Should we support continuous lines like normal comments?
          $value =~ s/^[\x09\x0A\x0C\x0D\x20]+//;
          $entry->autocomments->push ($value);
          $value =~ s/^[\x09\x0A\x0C\x0D\x20]+//;
          #$state = 'before msgid';
        } elsif ($value =~ s/^\?tag[\x09\x0A\x0C\x0D\x20]+//) {
          $entry->add_tag ($value);
          #$state = 'before msgid';
        } else {
          ## TODO: warning for unknown directive
          $value =~ s/^[\x09\x0A\x0C\x0D\x20]+//;
          $comment = $value;
          $state = 'in comment';
        }
      } elsif ($token->{type} eq 'eof') {
        ## TODO: warning if non-comment directive found
        $entry_set->footer = bless $entry, 'Popopo::Entry::Footer';
        undef $entry;
        last;
      } else {
        $self->{onerror}->(type => 'unexpected token',
                           token => $token,
                           level => $self->{level}->{po_fatal});
        undef $entry;
        $state = 'error';
      }
    } elsif ($state eq 'in comment') {
      if ($token->{type} eq 'directive' and
          $token->{value} !~ /^[,.:?]/ and
          $token->{value} !~ /^[\x09\x0A\x0C\x0D\x20]*$/) {
        my $value = $token->{value};
        $value =~ s/^[\x09\x0A\x0C\x0D\x20]+//;
        $comment .= length $comment ? "\x0A" . $value : $value;
        #$state = 'in comment';
      } elsif ($token->{type} eq 'eof') {
        if (length $comment or
            $entry->comments->length or
            $entry->locations->length or
            $entry->flags->length or
            $entry->tags->length) {
          $entry->comments->push ($comment) if length $comment;
          $state = 'before msgid';
          redo;
        } else {
          undef $entry;
          last;
        }
      } else {
        $entry->comments->push ($comment) if length $comment;
        $state = 'before msgid';
        redo;
      }
    } elsif ($state eq 'before msgid literal') {
      if ($token->{type} eq 'string') {
        $check_obsolete->();
        $entry->msgid .= $token->{value};
        $state = 'after msgid literal'
      } else {
        $self->{onerror}->(type => 'no msgid literal',
                           token => $token,
                           level => $self->{level}->{po_fatal});
        undef $entry;
        $state = 'error';
      }
    } elsif ($state eq 'after msgid literal') {
      if ($token->{type} eq 'string') {
        $check_obsolete->();
        $entry->msgid .= $token->{value};
        #$state = 'after msgid literal'
      } elsif ($token->{type} eq 'token' and $token->{value} eq 'msgstr') {
        $check_obsolete->();
        $state = 'before msgstr literal';
      } else {
        $self->{onerror}->(type => 'no msgstr',
                           token => $token,
                           level => $self->{level}->{po_fatal});
        undef $entry;
        $state = 'error';
      }
    } elsif ($state eq 'before msgstr literal') {
      if ($token->{type} eq 'string') {
        $check_obsolete->();
        $entry->msgstr .= $token->{value};
        $state = 'after msgstr literal'
      } else {
        $self->{onerror}->(type => 'no msgstr literal',
                           token => $token,
                           level => $self->{level}->{po_fatal});
        undef $entry;
        $state = 'error';
      }
    } elsif ($state eq 'after msgstr literal') {
      if ($token->{type} eq 'string') {
        $check_obsolete->();
        $entry->msgstr .= $token->{value};
        #$state = 'after msgstr literal'
      } else {
        $state = 'before entry';
        redo;
      }
    } elsif ($state eq 'error') {
      if ($token->{type} eq 'token' and $token->{value} eq 'msgid') {
        $state = 'before entry';
        redo;
      } elsif ($token->{type} eq 'eof') {
        last;
      } else {
        ## ignore a token
      }
    } else {
      die "Unknown state $state";
    }
  }
  $save_entry->($entry) if defined $entry;

  return $entry_set;
} # parse_string

=head1 NAME

Popopo::Parser - A PO Message Catalog File Parser

=head1 DESCRIPTION

The C<Popopo::Parser> module provides a PO (portable object) file
parser that generates a C<Popopo::EntrySet> object from the given
string.

The parser supports most parts of PO file syntax as implemented by the
C<msgfmt> command in the GNU gettext package, with the following
exceptions:

=over 4

=item

The C<Popopo::Parser> implements a error-tolerant parsing algorithm
that recovers from errors and resume parsing the file.  This feature
can be disabled by setting an C<onerror> handler that throws an
exception if its C<level> argument is equal to C<m>.

=item

The C<Popopo::Parser> implements an extended comment-like syntax for
assigning tags (or categories) to entries:

  #?tag TAG1
  #?tag TAG2
  msgid "tagged entry"
  msgstr "Tagged String"

=back

=head1 BUGS

Plural forms are not supported yet.

Character encodings other than UTF-8 (with utf8 flag set) are not
supported yet.

=head1 DEPENDENCY

This module requires Perl 5.8 or later.

=head1 SEE ALSO

L<Popopo::EntrySet>, L<Popopo::Entry> - In-memory representations of
PO files.

L<Popopo::Checker> - PO validity checker.

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
