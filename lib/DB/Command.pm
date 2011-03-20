package DB::Command;

use strict;
use warnings;

use base 'Clib::DBIC';

__PACKAGE__->table("command");
__PACKAGE__->columns_array(qw/id dtadd blkid name/);

__PACKAGE__->link(blok => 'Blok', blkid => 'id', {join_type => 'left'});
__PACKAGE__->link(ausweis => 'Ausweis', id => 'cmdid');

sub create {
    my ($self, $new) = @_;
    
    if (ref($new) eq 'HASH') {
        $new->{dtadd} ||= \ 'NOW()';
    }
    
    return $self->SUPER::create($new);
}


1;
