package DB::Msg;

use strict;
use warnings;

use base 'Clib::DBIC';

__PACKAGE__->table("msg");
__PACKAGE__->columns_array(qw/id uid cmdid dtadd readed mailed txt/);

__PACKAGE__->link(user => 'UserList', uid => 'id', {join_type => 'left'});
__PACKAGE__->link(command => 'Command', cmdid => 'id', {join_type => 'left'});

sub create {
    my ($self, $new) = @_;
    
    if (ref($new) eq 'HASH') {
        $new->{dtadd} ||= \ 'NOW()';
    }
    
    return $self->SUPER::create($new);
}

1;
