package DB::UserList;

use strict;
use warnings;

use base 'Clib::DBIC';

__PACKAGE__->table("user_list");
__PACKAGE__->columns_hash(
    id          => { skip => 1 },
    dtadd       => { skip => 1 },
    login       => 's',
    password    => { type => 'r', not_empty => 1, confirm => 'pass2' },
    name        => '!s',
    family      => '!s',
    phone       => '!s', 
    phone2      => 's',
);

sub create {
    my ($self, $new) = @_;
    
    if (ref($new) eq 'HASH') {
        $new->{dtadd} ||= \ 'NOW()';
    }
    
    return $self->SUPER::create($new);
}


1;
