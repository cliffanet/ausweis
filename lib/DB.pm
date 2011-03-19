package DB;

use strict;
use base 'Clib::DBIC::Schema';

require "$::pathRoot/conf/defines.conf";

my $socket = $::db_Main{socket} ? ";mysql_socket=$::db_Main{socket}" : "";

__PACKAGE__->config(
    connect_info => [
        "dbi:mysql:database=$::db_Main{name};host=$::db_Main{host}$socket",
        $::db_Main{user},
        $::db_Main{password},
        { RaiseError => 0 },
        {
            on_connect_do => [ 'set names cp1251' ],
            auto_reconnect => 1,
        },
    ],
);

1;
