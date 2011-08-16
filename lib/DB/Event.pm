package DB::Event;

use strict;
use warnings;

use base 'Clib::DBIC';

__PACKAGE__->table("event");
__PACKAGE__->columns_hash(
    id          => { skip => 1 },
    dtadd       => { skip => 1 },
    date        => { type => 's' },
    status      => { type => 's', pattern => '^[OZ]$' },
    name        => '!s',
    price       => 'f',
);

sub create {
    my ($self, $new) = @_;
    
    if (ref($new) eq 'HASH') {
        $new->{dtadd} ||= \ 'NOW()';
        $new->{status} ||= 'O';
    }
    
    return $self->SUPER::create($new);
}

1;
