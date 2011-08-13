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
        $sth->execute($eid, $f, $value, $o) || return;
        $count ++;
    }
    $sth->finish;
    
    $count;
}

1;
