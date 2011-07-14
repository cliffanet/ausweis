package DB::Blok;

use strict;
use warnings;

use base 'Clib::DBIC';

__PACKAGE__->table("blok");
__PACKAGE__->columns_hash(
    id          => { skip => 1 },
    dtadd       => { skip => 1 },
    name        => '!s',
    photo       => { skip => 1 },
);

sub create {
    my ($self, $new) = @_;
    
    if (ref($new) eq 'HASH') {
        $new->{dtadd} ||= \ 'NOW()';
    }
    
    return $self->SUPER::create($new);
}


1;
