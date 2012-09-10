package DB::EventAusweis;

use strict;
use warnings;

use base 'Clib::DBIC';

__PACKAGE__->table("event_ausweis");
__PACKAGE__->columns_array(qw/id dtadd evid ausid cmdid price payonkpp/);

__PACKAGE__->link(event => 'Event', evid => 'id');
__PACKAGE__->link(ausweis => 'Ausweis', ausid => 'id');
__PACKAGE__->link(command => 'Command', cmdid => 'id');

sub create {
    my ($self, $new) = @_;
    
    if (ref($new) eq 'HASH') {
        $new->{dtadd} ||= \ 'NOW()';
        $new->{evid} || return;
        $new->{ausid} || return;
        $new->{cmdid} || return;
    }
    
    return $self->SUPER::create($new);
}


1;
