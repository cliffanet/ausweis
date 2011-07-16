package DB::Command;

use strict;
use warnings;

use base 'Clib::DBIC';

__PACKAGE__->table("command");
__PACKAGE__->columns_hash(
    id          => { skip => 1 },
    dtadd       => { skip => 1 },
    blkid       => { type => 'd', handler => \&DB::Block::hnd_blkid },
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


#######################################################################
sub hnd_cmdid {
    my ($self, $param, $index, $value, $ptr) = @_;
    
    return 0 unless $value;
    
    ($self->d->{command}) = $self->model('Command')->search({ id => $value });
    return $self->d->{command} ? 0 : 12;
}


1;
