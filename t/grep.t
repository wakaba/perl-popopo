use strict;
use warnings;
use Path::Class;
use lib glob file(__FILE__)->dir->parent->subdir('t_deps', 'modules', '*', 'lib');
use Test::More;
use Test::X1;
use Popopo::Grep;

test {
    my $c = shift;
    my $refs = {};
    my $urls = {};
    
    my $dir = file(__PACKAGE__)->dir->subdir('t_deps', 'data-loc');
    Popopo::Grep->find_refs($dir, sub {
        my ($file_name, $line_number, $msgid, $method_name, $args) = @_;
        
        $refs->{$msgid} = {
            file_name => $file_name,
            line_number => $line_number,
            method_name => $method_name,
            args => $args,
        };
    }, sub {
        my ($file_name, $url) = @_;

        like $file_name, qr[t_deps/data-loc/loc.dat$], 'loc_url';
    });

    my $line = 3;

    {
        ok $refs->{abc};
        is $refs->{abc}->{line_number}, $line++;
        is $refs->{abc}->{method_name}, 'loc';
    }

    {
        ok $refs->{abcd};
        is $refs->{abcd}->{line_number}, $line++;
        is $refs->{abcd}->{method_name}, 'locale->text';
    }

    {
        ok $refs->{abcde};
        is $refs->{abcde}->{line_number}, $line++;
        is $refs->{abcde}->{method_name}, "the('locale')->text";
    }

    $line++;

    {
        ok $refs->{'images.ijk'};
        is $refs->{'images.ijk'}->{line_number}, $line++;
        is $refs->{'images.ijk'}->{method_name}, 'loc_img';
    }

    {
        ok $refs->{'images.ijkl'};
        is $refs->{'images.ijkl'}->{line_number}, $line++;
        is $refs->{'images.ijkl'}->{method_name}, 'loc_img_abs';
    }

    {
        ok $refs->{'images.ijklm'};
        is $refs->{'images.ijklm'}->{line_number}, $line++;
        is $refs->{'images.ijklm'}->{method_name}, 'loc_img_src';
    }

    {
        ok $refs->{'images.ds.ijklmn'};
        is $refs->{'images.ds.ijklmn'}->{line_number}, $line++;
        is $refs->{'images.ds.ijklmn'}->{method_name}, 'loc_img_umt';
    }

    {
        ok $refs->{'images.ijklmno'};
        is $refs->{'images.ijklmno'}->{line_number}, $line++;
        is $refs->{'images.ijklmno'}->{method_name}, 'loc_input_image';
    }

    $line++;

    {
        ok $refs->{nmo};
        is $refs->{nmo}->{line_number}, $line++;
        is $refs->{nmo}->{method_name}, 'loc_n';
    }

    {
        ok $refs->{nmop};
        is $refs->{nmop}->{line_number}, $line++;
        is $refs->{nmop}->{method_name}, 'loc_n';
    }

    {
        ok $refs->{nmopq};
        is $refs->{nmopq}->{line_number}, $line++;
        is $refs->{nmopq}->{method_name}, 'locale->text_n';
    }

    {
        ok $refs->{nmopqr};
        is $refs->{nmopqr}->{line_number}, $line++;
        is $refs->{nmopqr}->{method_name}, 'locale->text_n';
    }

    {
        ok $refs->{nmopqrs};
        is $refs->{nmopqrs}->{line_number}, $line++;
        is $refs->{nmopqrs}->{method_name}, "the('locale')->text_n";
    }

    $line++;

    {
        ok not $refs->{l1};
        $line++;
    }
    
    {
        ok $refs->{l2};
        is $refs->{l2}->{line_number}, $line++;
        is $refs->{l2}->{method_name}, 'l';
    }

    {
        ok not $refs->{l3};
        $line++;
    }

    $line++;
    
    {
        ok $refs->{'terms.article'};
        is $refs->{'terms.article'}->{line_number}, $line;
        is $refs->{'terms.article'}->{method_name}, 'loc';
    }
    {
        ok $refs->{'ugomemo.eula.hatena.a6'};
        is $refs->{'ugomemo.eula.hatena.a6'}->{line_number}, $line++;
        is $refs->{'ugomemo.eula.hatena.a6'}->{method_name}, 'loc';
    }

    $line++;
    
    {
        ok $refs->{m1};
        is $refs->{m1}->{line_number}, $line++;
        is $refs->{m1}->{method_name}, 'Hatena.Locale.text';
    }

    {
        ok $refs->{m2};
        is $refs->{m2}->{line_number}, $line++;
        is $refs->{m2}->{method_name}, 'Hatena.Locale.text_n';
    }

    $line++;
    
    {
        ok $refs->{abc1};
        is $refs->{abc1}->{line_number}, $line++;
        is $refs->{abc1}->{method_name}, 'tloc';
    }
    
    {
        ok $refs->{abc2};
        is $refs->{abc2}->{line_number}, $line++;
        is $refs->{abc2}->{method_name}, 'hloc';
    }
    
    {
        ok not $refs->{abc3};
        $line++;
        #ok $refs->{abc3};
        #is $refs->{abc3}->{line_number}, $line++;
        #is $refs->{abc3}->{method_name}, 'etloc';
    }

    $line++;
    
    {
        ok $refs->{abc4};
        is $refs->{abc4}->{line_number}, $line++;
        is $refs->{abc4}->{method_name}, 'eloc';
    }
    
    {
        ok not $refs->{abc5};
        $line++;
        #ok $refs->{abc5};
        #is $refs->{abc5}->{line_number}, $line++;
        #is $refs->{abc5}->{method_name}, 'ehloc';
    }
    done $c;
} n => 68, name => 'find refs';

run_tests;
