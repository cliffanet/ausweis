package DB::AdminGroup;

use strict;
use warnings;

use base 'Clib::DBIC';

__PACKAGE__->table("admin_group");
__PACKAGE__->columns_array(qw/id name rights/);


1;
