package V::Excel;

use strict;
use base 'Clib::View::Excel';

=head2
    ����������� �������������
=cut
__PACKAGE__->config(
    FilesPath => "$::pathRoot/texcel",
);

1;
