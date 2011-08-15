package DB::EventAusweis;

use strict;
use warnings;

use base 'Clib::DBIC';

__PACKAGE__->table("event_ausweis");
__PACKAGE__->columns_array(qw/id evid ausid/);

sub create {
    my ($self, $new) = @_;
    
    if (ref($new) eq 'HASH') {
        $new->{evid} || return;
        $new->{ausid} || return;
    }
    
    return $self->SUPER::create($new);
}


1;
