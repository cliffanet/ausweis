package DB::EventMoney;

use strict;
use warnings;

use base 'Clib::DBIC';

__PACKAGE__->table("event_money");
__PACKAGE__->columns_array(qw/id evid cmdid summ price1 price2 comment/);

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
    $m ||= { summ => '0.00', price1 => '0.00', price2 => '0.00', comment => '', is_null => 1 };
    return $m;
}

sub set {
    my ($self, $evid, $cmdid, $rec) = @_;
    
    my ($m) = $self->search({ evid => $evid, cmdid => $cmdid });
    return $m ?
        $self->update($rec, { id => $m->{id} }) :
        $self->create({ %$rec, evid => $evid, cmdid => $cmdid });
}

sub summ_add {
    my ($self, $evid, $cmdid, $summ) = @_;
    
    my ($m) = $self->search({ evid => $evid, cmdid => $cmdid });
    if ($m) {
        return $self->update({ summ => $m->{summ}+$summ }, { id => $m->{id} });
    }
    else {
        my $new = { evid => $evid, cmdid => $cmdid, summ => $summ };
        my ($ev) = $self->schema->model('Event')->search({ id => $evid });
        if ($ev) {
            $new->{price1} = $ev->{price1};
            $new->{price2} = $ev->{price2};
        }
        return $self->create($new);
    }
    
    undef;
}


1;
