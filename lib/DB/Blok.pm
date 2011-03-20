package DB::Blok;

use strict;
use warnings;

use base 'Clib::DBIC';

__PACKAGE__->table("blok");
__PACKAGE__->columns_array(qw/id dtadd name/);

sub create {
    my ($self, $new) = @_;
    
    if (ref($new) eq 'HASH') {
        $new->{dtadd} ||= \ 'NOW()';
    }
    
    return $self->SUPER::create($new);
}


1;
