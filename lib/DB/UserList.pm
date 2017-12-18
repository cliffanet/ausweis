package DB::UserList;

use strict;
use warnings;

use base 'Clib::DBIC';

__PACKAGE__->table("user_list");
__PACKAGE__->columns_array(qw/id login password gid cmdid rights menuflag family name otch phone email/);

__PACKAGE__->link(group => 'UserGroup', gid => 'id', {join_type => 'left'});
__PACKAGE__->link(session => 'UserSession', id => 'uid', {join_type => 'left'});
__PACKAGE__->link(command => 'Command', cmdid => 'id', {join_type => 'left'});

sub create {
    my ($self, $new) = @_;
    
    if (ref($new) eq 'HASH') {
        $new->{dtadd} ||= \ 'NOW()';
    }
    
    return $self->SUPER::create($new);
}


1;
