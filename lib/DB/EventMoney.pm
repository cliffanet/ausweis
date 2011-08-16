package DB::EventMoney;

use strict;
use warnings;

use base 'Clib::DBIC';

__PACKAGE__->table("event_money");
__PACKAGE__->columns_array(qw/id evid cmdid summ price comment/);

sub create {
    my ($self, $new) = @_;
    
    if (ref($new) eq 'HASH') {
        $new->{evid} || return;
        $new->{cmdid} || return;
    }
    
    return $self->SUPER::create($new);
}

sub get {
    my ($self, $evid, $cmdid) = @_;
    
    my ($m) = $self->search({ evid => $evid, cmdid => $cmdid });
    $m ||= { summ => '0.00', price => '0.00', comment => '' };
    return $m;
}

sub set {
    my ($self, $evid, $cmdid, $rec) = @_;
    
    my ($m) = $self->search({ evid => $evid, cmdid => $cmdid });
    return $m ?
        $self->update($rec, { id => $m->{id} }) :
        $self->create({ %$rec, evid => $evid, cmdid => $cmdid });
}


1;
