package V::Excel;

use strict;
use base 'Clib::View::ExcelUTF8';

=head2
    ����������� �������������
=cut
__PACKAGE__->config(
    FilesPath => "$::pathRoot/texcel",
);

1;
