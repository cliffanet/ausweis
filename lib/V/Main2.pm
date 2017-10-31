package V::Main2;

use strict;
use base qw/
        Clib::View::Package
    /;

=head2
    Стандартная инициализация
=cut
__PACKAGE__->config(
    basetemplate        => "base",
    FILE_DIR_RELATIVE   => "template",
    $::isDevel ? (
        MODULE_DIR_RELATIVE => "../../template.cach/ausweis",
        FORCE_REBUILD       => 1,
    ) : (),
    PLUGIN              => [qw/Block Misc/],
    JQUERY              => 1,
    USE_UTF8            => 1,
    'Content-type'      => 'text/html; charset=utf-8',
);

1;
