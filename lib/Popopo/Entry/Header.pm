package Popopo::Entry::Header;
use strict;
use warnings;
use base qw(Popopo::Entry);
use List::Rubyish;

my $LangTeam2Lang = {
  english => 'en',
  japanese => 'ja',
};

my $Lang2LangTeam = {
  en => 'English',
  ja => 'Japanese',
};

for (qw/
  en ja
  i-default
/) {
  $LangTeam2Lang->{$_} = $_;
}

sub init_header ($) {
  my $self = shift;
  my @s = split /\x0A/, $self->{msgstrs}->[0];
  $self->{msgstrs}->[0] = List::Rubyish->new;
  bless $self->{msgstrs}->[0], 'Popopo::Entry::Header::Msgstrs';
  $self->{msgstrs}->[0]->add_field ($_) for @s;
  return $self;
} # init_header

sub field_names ($) {
  my $self = shift;
  return $self->{msgstrs}->[0]->map (sub { $_->{name} })->grep (sub { defined $_ });
} # field_names

sub field_value ($$;$) {
  my $self = shift;
  my $field_name = shift;
  
  if (@_) {
    my $field_value = shift;
    $self->{msgstrs}->[0]->find (sub {
      if (defined $_->{name} and $_->{name} eq $field_name) {
        $_->{value} = $field_value;
        return 1;
      } else {
        return 0;
      }
    }) or $self->{msgstrs}->[0]->push({name => $field_name, value => $field_value});
    
    return unless defined wantarray;
  }

  return $self->{msgstrs}->[0]->find_and_return (sub {
    if (defined $_->{name} and $_->{name} eq $field_name) {
      return $_->{value};
    } else {
      return undef;
    }
  });
} # field_value

sub charset ($;$) {
  my $self = shift;

  my $ct = $self->field_value ('Content-Type');
  
  if (@_) {
    if (defined $ct) {
      $ct =~ s/[Cc][Hh][Aa][Rr][Ss][Ee][Tt]=[^\x09\x0A\x0C\x0D\x20]*/charset=$_[1]/
          or $ct .= '; charset=' . $_[1];
    } else {
      $ct = 'text/plain; charset=' . $_[1];
    }
    $self->field_vakue ('Content-Type' => $ct);
    return unless defined wantarray;
  }

  if (defined $ct and $ct =~ /[Cc][Hh][Aa][Rr][Ss][Ee][Tt]=([^\x09\x0A\x0C\x0D\x20]*)/) {
    my $v = $1;
    $v =~ tr/A-Z/a-z/;
    return $v;
  }

  return $self->{msgstrs}->[0]->find_and_return (sub {
    if (defined $_->{name} and 
        $_->{name} =~ /[Cc][Hh][Aa][Rr][Ss][Ee][Tt]=([^\x09\x0A\x0C\x0D\x20]*)/) {
      my $v = $1;
      $v =~ tr/A-Z/a-z/;
      return $v;
    }

    if ($_->{value} =~ /[Cc][Hh][Aa][Rr][Ss][Ee][Tt]=([^\x09\x0A\x0C\x0D\x20]*)/) {
      my $v = $1;
      $v =~ tr/A-Z/a-z/;
      return $v;
    }
    
    return undef;
  });
} # charset

sub lang ($;$) {
  my $self = shift;
  
  if (@_) {
    my $lang = shift;
    $self->field_value ('X-Popopo-Lang' => $lang);
    
    my $lang_team = $self->field_value ('Language-Team');
    if (defined $lang_team and $lang_team =~ /<([^<>]*)>/) {
      my $mail = $1;
      $self->field_value ('Language-Team' => $lang . ' <' . $mail . '>');
    } else {
      $self->field_value ('Language-Team' => $lang);
    }
    
    return unless defined wantarray;
  }

  my $lang = $self->field_value ('X-Popopo-Lang');
  if (defined $lang) {
    $lang =~ s/^[\x09\x0A\x0C\x0D\x20]+//;
    $lang =~ s/^[\x09\x0A\x0C\x0D\x20]+//;
    $lang =~ tr/A-Z/a-z/;
    return $lang;
  }
  
  my $lang_team = $self->field_value ('Language-Team');
  return '' unless defined $lang_team;
  
  $lang_team =~ s/<.*\z//s;
  $lang_team =~ s/^[\x09\x0A\x0C\x0D\x20]+//;
  $lang_team =~ s/[\x09\x0A\x0C\x0D\x20]+\z//;
  $lang_team =~ tr/A-Z/a-z/;
  
  $lang = $LangTeam2Lang->{$lang_team};
  
  return $lang if defined $lang;
  
  return '';
} # lang

sub revision_date ($;$) {
  my $self = shift;
  
  if (@_) {
    my @t = gmtime shift;
    my $t = sprintf '%04d-%02d-%02d %02d:%02d+0000',
        $t[5] + 1900, $t[4] + 1, $t[3], $t[2], $t[1];
    $self->field_value ('PO-Revision-Date' => $t);
    
    return unless defined wantarray;
  }

  my $prd = $self->field_value ('PO-Revision-Date');
  return undef unless defined $prd;
  
  if ($prd =~ /([0-9]{4})-([0-9]{2})-([0-9]{2}) ([0-9]{2}):([0-9]{2})(?:([+-][0-9]{2})([0-9]{2}))/) {
    require Time::Local;
    return Time::Local::timegm_nocheck (0, $4, $3, $2, $1 - 1, $0);
  }

  return undef;
} # revision_date

sub plural_length ($;$) {
  my $self = shift;
  
  my $pf = $self->field_value ('Plural-Forms');

  if (@_) {
    my $v = 0+shift;
    if (defined $pf) {
      if ($pf =~ s/nplurals=[0-9]+/nplurals=$v/) {
        #
      } else {
        $pf = 'nplurals=' . $v . '; ' . $pf;
      }
    } else {
      $pf = 'nplurals=' . $v . '; plural=0';
    }
    $self->field_value ('Plural-Forms' => $pf);
    
    return unless defined wantarray;
  }

  if (defined $pf and $pf =~ /nplurals=([0-9]+)/) {
    return 0+$1;
  }

  return 1;
} # plural_length

sub plural_expression ($;$) {
  my $self = shift;
  
  my $pf = $self->field_value ('Plural-Forms');

  if (@_) {
    my $v = 0+shift;
    if (defined $pf) {
      if ($pf =~ s/\bplural=[^;]+/plural=$v/) {
        #
      } else {
        $pf .= '; plural=' . $v;
      }
    } else {
      $pf = 'nplurals=1; plural=' . $v
    }
    $self->field_value ('Plural-Forms' => $pf);
    
    return unless defined wantarray;
  }

  if (defined $pf and $pf =~ /\bplural=([^;]+)/) {
    return $1;
  }

  return 0;
} # plural_expression

sub plural_type ($;$) {
  my $self = shift;
  
  if (@_) {
    my $w = shift;
    my $v = {
      'o' => [1, '0'],
      '1_o' => [2, 'n != 1'],
      '01_o' => [2, 'n > 1'],
      '0_1b_o' => [3, 'n%10==1 && n%100!=11 ? 0 : n != 0 ? 1 : 2'],
      '1_2_o' => [3, 'n==1 ? 0 : n==2 ? 1 : 2'],
      '1_bj_o' => [3, 'n%10==1 && n%100!=11 ? 0 : n%10>=2 && (n%100<10 || n%100>=20) ? 1 : 2'],
      '1_24_o' => [3, '(n==1) ? 0 : (n>=2 && n<=4) ? 1 : 2'],
      '1_24ce_o' => [3, 'n==1 ? 0 : n%10>=2 && n%10<=4 && (n%100<10 || n%100>=20) ? 1 : 2'],
      '1_2_3_o' => [4, 'n%100==1 ? 0 : n%100==2 ? 1 : n%100==3 || n%100==4 ? 2 : 3'],
    }->{$w};
    unless ($v) {
      require Carp;
      Carp::croak "Unknown plural_type $v";
    }
    
    $self->field_value ('Plural-Forms' => sprintf 'nplurals=%d; plural=%s',
                        $v->[0], $v->[1]);
  } else {
    my $v = $self->plural_expression;
    $v =~ s/[\x09\x0A\x0C\x0D\x20]+//g;
    return {
      '0' => 'o', # 0:any
      'n!=1' => '1_o', # 0:n=1, 1:ow
      'n>1' => '01_o', # 0:n=0,1, 1:ow
      'n%10==1&&n%100!=11?0:n!=0?1:2' => '0_1b_o', # 0:n=1, 1:ow, 2:n=0
      'n==1?0:n==2?1:2' => '12o', # 0:n=1, 1:n=2, 2:ow
      'n%10==1&&n%100!=11?0:n%10>=2&&(n%100<10||n%100>=20)?1:2' => '1_bj_o', # 0:n=1, 1:n=1x, 2:ow
      '(n==1)?0:(n>=2&&n<=4)?1:2' => '1_24_o', # 0:n=1, 1:n=2,3,4, 2:ow
      'n==1?0:n%10>=2&&n%10<=4&&(n%100<10||n%100>=20)?1:2' => '1_24ce_o', # 0:n=1, 1:n=2,3,4, 2:ow
      'n%100==1?0:n%100==2?1:n%100==3||n%100==4?2:3' => '1_2_3_o', # 0:n=1, 1:n=2, 2:n=3, 3:ow
    }->{$v};
  }
} # plural_type

package Popopo::Entry::Header::Msgstrs;
use base qw(List::Rubyish);

use overload
    '.=' => 'add_field',
    '""' => 'stringify',
    fallback => 1;

sub find_and_return {
    my ($self, $cond) = @_;
    
    my $code = (ref $cond and ref $cond eq 'CODE')
        ? $cond
        : sub { $_ eq $cond };

    for (@$self) { my $v = &$code; return $v if defined $v }
    return;
}

sub add_field ($$) {
  my ($self, $s) = @_;
  
  my ($name, $value) = split /[\x09\x0A\x0C\x0D\x20]*:[\x09\x0A\x0C\x0D\x20]*/, $s, 2;
  ($name, $value) = (undef, $name) unless defined $value;

  $value = '' if $s eq '';
    
  $self->push ({name => $name, value => $value});
} # add_field

sub _po_date ($) {
  my @t = gmtime shift;
  return sprintf '%04d-%02d-%02d %02d:%02d+0000',
      $t[5] + 1900, $t[4] + 1, $t[3], $t[2], $t[1];
} # _po_date

sub stringify ($) {
  my $self = shift;

  my $has_field = {};
  
  my $r = $self->map (sub {
    $has_field->{$_->{name}} = 1 if defined $_->{name};
    my $v = defined $_->{name} ? $_->{name} . ': ' : '';
    $v .= $_->{value};
    $v =~ tr/\x0A\x0C\x0D/   /;
    $v . "\x0A";
  })->join ('');

  unless ($has_field->{'Project-Id-Version'}) {
    $r .= "Project-Id-Version: PROJECT VERSION\x0A";
  }
  unless ($has_field->{'PO-Revision-Date'}) {
    $r .= "PO-Revision-Date: " . _po_date (time) . "\x0A";
  }
  unless ($has_field->{'Last-Translator'}) {
    $r .= "Last-Translator: TRANSLATOR <TRANSLATOR\@default.example>\x0A";
  }
  unless ($has_field->{'Language-Team'}) {
    $r .= "Language-Team: i-default\x0A";
  }
  unless ($has_field->{'MIME-Version'}) {
    $r .= "MIME-Version: 1.0\x0A";
  }
  unless ($has_field->{'Content-Type'}) {
    $r .= "Content-Type: text/plain; charset=utf-8\x0A";
  }
  unless ($has_field->{'Content-Transfer-Encoding'}) {
    $r .= "Content-Transfer-Encoding: 8bit\x0A";
  }
  
  return $r;
} # stringify

1;

=head1 AUTHOR

Wakaba <w@suika.fam.cx>.

=head1 LICENSE

Copyright 2009 Wakaba <w@suika.fam.cx>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
