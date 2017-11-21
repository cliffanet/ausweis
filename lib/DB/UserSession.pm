package DB::UserSession;

use strict;
use warnings;

use base 'Clib::DBIC';

__PACKAGE__->table("user_session");
__PACKAGE__->columns_array(qw/id key ip uid state create visit/);


__PACKAGE__->link('user', 'UserList', 'uid', 'id', { join_type => 'left' });

1;
