package Popopo::Grep;
use strict;
use warnings;

sub find_refs {
    my ($class, $dir_name, $code, $url_code) = @_;
    local $_;
    
    open my $loc, '-|', 'grep', 'loc\|\<l\>\|Locale\.text', '-n', -R => $dir_name or die "$0: grep -R $dir_name: $!";
    while (<$loc>) {
        my $file_name = '';
        my $line_number = 0;
        if (/^([^:]+):(\d+):/) {
            $file_name = $1;
            $line_number = 0+$2;
        }

        while (/\b((?:h|t)?loc(?:ale->text|_img(?:_(?:abs|src|umt))?|_input_image)?(?:_localized)?(?:_n)?|the\('locale'\)->text(?:_n)?|l|Hatena\.Locale\.text(?:_n)?)\s*\(\s*["']([^"']+)["'](?=([^()]*))/g) {
            my $method_name = $1;
            my $msgid = $2;
            my $args = $3;

            if ($method_name =~ /img_umt/) {
                $msgid = "images.ds.$msgid";
            } elsif ($method_name =~ /img|image/) {
                $msgid = "images.$msgid";
            }
            
            1 while $msgid =~ s/\s*\[_\d+\]\s*$//;
            1 while $msgid =~ s/\s*%\d+\s*$//;
            
            $code->($file_name, $line_number, $msgid, $method_name, $args);
        }

        while (/\b(eloc)\s*\(['"].*?['"]\s*,\s*['"]([^'"]+)['"](?=([^()]*))/gs) {
            $code->($file_name, $line_number, $2, $1, $3);
        }

        while (/'([^']+)'[^']*\bloc\(\)/g) {
            $code->($file_name, $line_number, $1, 'loc', undef);
        }

        # locs() / text_with_args() はたぶん msgid 直書きしないのでチェッ
        # クしない

        if (/\bloc_url\s*<([^<>]+)>/) {
            my $url = $1;
            
            $url_code->($file_name, $url) if $url_code;
        }
    }
    close $loc;
}

sub find_defs {
    my ($class, $dir_name, $code) = @_;
    
    opendir my $po_dir, $dir_name or die "$0: $dir_name: $!";
    while (defined (my $po_file_name = readdir $po_dir)) {
        if ($po_file_name =~ /\.po$/) {
            my $lang = $po_file_name;
            $lang =~ s/\.po$//;
            $po_file_name = "$dir_name/$po_file_name";
            
            local $/ = undef;
            open my $po_file, '<:encoding(utf-8)', $po_file_name or warn "$0: $po_file_name: $!";
            my $po_data = <$po_file>;
            
            $po_data =~ s{msgid\s*"([^"]+)"}{
                my $msgid = $1;
                1 while $msgid =~ s/\s*%\d+\s*$//;
                $code->($po_file_name, $lang, $msgid);
            }ge;
        }
    }
    close $po_dir;
}

1;

=head1 LICENSE

Copyright 2009 Hatena <http://www.hatena.ne.jp/company/>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
