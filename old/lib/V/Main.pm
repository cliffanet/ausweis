package V::Main;

use strict;
use base qw/
        Clib::View::TT
    /;

=head2
    Стандартная инициализация
=cut
__PACKAGE__->config(
    mould       => "base.tt",
    INCLUDE_PATH=> "$::pathRoot/tt",
);


1;
