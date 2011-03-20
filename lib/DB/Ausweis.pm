package DB::Ausweis;

use strict;
use warnings;

use base 'Clib::DBIC';

__PACKAGE__->table("ausweis");
__PACKAGE__->columns_array(qw/id dtadd numid nick cmdid/);

sub create {
    my ($self, $new) = @_;
    
    if (ref($new) eq 'HASH') {
        $new->{dtadd} ||= \ 'NOW()';
    }
    
    return $self->SUPER::create($new);
}


1;
