package DB;

use strict;
use base 'Clib::DBIC::Schema';

__PACKAGE__->config(
    connect_by_const => 'db',
    connect_info => [
        { RaiseError => 0, mysql_enable_utf8 => 1 },
        {
            on_connect_do => [ 'set names utf8' ],
            auto_reconnect => 1,
        },
    ],
);

1;
