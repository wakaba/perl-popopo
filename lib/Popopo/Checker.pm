=pod

To be written.

TOOD:

#~ msgid "" msgstr "..."
(not supported by gettext)

#,fuzzy
msgid ""
msgstr "..."
(warned by gettext)

CHARSET=...
(supported by gettext msgfmt but not by msgunfmt)

msgid ""
msgstr ""
(ditto)

\r, \f, ...
(warned by gettext)

\0
(breaks gettext)

msgid ""
msgid_plural "..."
msgstr[0] "..."
(not supported by gettext (ignored))

msgid "..."
msgid_plural ""
(supported by gettext but confusing)

=head1 AUTHOR

Wakaba <w@suika.fam.cx>.

=head1 LICENSE

Copyright 2009 Wakaba <w@suika.fam.cx>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
