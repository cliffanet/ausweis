package DB::Command;

use strict;
use warnings;

use base 'Clib::DBIC';

__PACKAGE__->table("command");
__PACKAGE__->columns_hash(
    id          => { skip => 1 },
    dtadd       => { skip => 1 },
    blkid       => { type => 'd', handler => \&DB::Blok::hnd_blkid },
    regen       => { skip => 1 },
    name        => '!s',
    photo       => { skip => 1 },
);

__PACKAGE__->link(blok => 'Blok', blkid => 'id', {join_type => 'left'});
__PACKAGE__->link(ausweis => 'Ausweis', id => 'cmdid');

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
sub hnd_cmdid {
    my ($self, $param, $index, $value, $ptr) = @_;
    
    return 0 unless $value;
    
    ($self->d->{command}) = $self->model('Command')->search({ id => $value });
    return $self->d->{command} ? 0 : 12;
}


1;
