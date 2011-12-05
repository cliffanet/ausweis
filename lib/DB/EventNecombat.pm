package DB::EventNecombat;

use strict;
use warnings;

use base 'Clib::DBIC';

__PACKAGE__->table("event_necombat");
__PACKAGE__->columns_array(qw/id dtadd evid cmdid name/);

__PACKAGE__->link(command => 'Command', cmdid => 'id', {join_type => 'left'});

sub create {
    my ($self, $new) = @_;
    
    if (ref($new) eq 'HASH') {
        $new->{dtadd} ||= \ 'NOW()';
        $new->{evid} || return;
        $new->{cmdid} || return;
    }
    
    return $self->SUPER::create($new);
}


1;
