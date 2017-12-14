package DB::Blok;

use strict;
use warnings;

use base 'Clib::DBIC';

__PACKAGE__->table("blok");
__PACKAGE__->columns_hash(
    id          => { skip => 1 },
    dtadd       => { skip => 1 },
    regen       => { skip => 1 },
    name        => '!s',
    photo       => { skip => 1 },
);

__PACKAGE__->link(command => 'Command', id => 'blkid', {join_type => 'left'});

sub create {
    my ($self, $new) = @_;
    
    if (ref($new) eq 'HASH') {
        $new->{dtadd} ||= \ 'NOW()';
    }
    
    return $self->SUPER::create($new);
}

sub regen_off {
    my ($self, $id, @bnum) = @_;
    
    my $count = '0';
    foreach my $bnum (@bnum) {
        $bnum || next;
        my $b = 1 << ($bnum-1);
        
        my $sql = "UPDATE `$self->{_table}` SET `regen` = `regen` ^ ? WHERE `id` = ?";
    
        $self->do(sql => $sql, params => [$b, $id]) || return;
        
        $count ++;
    }
    
    return $count;
}


#######################################################################
sub hnd_blkid {
    my ($self, $param, $index, $value, $ptr) = @_;
    
    return 0 unless $value;
    
    my ($item) = $self->model('Blok')->search({ id => $value });
    return $item ? 0 : 11;
}

1;
