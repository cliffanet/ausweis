package V::Excel;

use strict;
use base 'Clib::View::Excel';

=head2
    Стандартная инициализация
=cut
__PACKAGE__->config(
    FilesPath => "$::pathRoot/texcel",
);

1;
