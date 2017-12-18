package DB::PreeditField;

use strict;
use warnings;

use base 'Clib::DBIC';

__PACKAGE__->table("preedit_field");
__PACKAGE__->columns_array(qw/id eid param value old/);

__PACKAGE__->link( edit => 'Preedit', eid => 'id' );

sub add {
    my ($self, $eid, $fields, $old) = @_;
    
    $eid || return;
    $fields || return;
    my @list = keys %$fields;
    @list || return;
    
    my $count = '0E0';
    my $sth = $self->SUPER::create([qw/eid param value old/]) || return;
    foreach my $f (@list) {
        my $value = $fields->{$f};
        $value = "=> $$value" if ref($value) eq 'SCALAR';
        my $o = $old && exists($old->{$f}) ? $old->{$f} : undef;
        next if defined($o) && ($o eq $value);
        #use Data::Dumper;
        #$self->r->debug("preedit fields: %s", Dumper [$eid, $f, $value, $o]);
        $sth->execute($eid, $f, $value, $o) || return;
        $count ++;
    }
    $sth->finish;
    
    $count;
}

sub get {
    my ($self, $eid, %args) = @_;
    
    my $pre = ref($eid) eq 'HASH' ? $eid : { id => $eid };
    $eid = $pre->{id};
    
    $args{eid} = $eid;
    return {
        map { ($_->{param} => $_) }
        $self->search(\%args)
    }
}

sub get_value {
    my ($self, $eid, %args) = @_;
    
    my $h = $self->get($eid, %args) || return;
    return { map { ($_ => $h->{$_}->{value}) } keys %$h };
}


1;
