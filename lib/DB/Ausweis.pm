package DB::Ausweis;

use strict;
use warnings;

use base 'Clib::DBIC';

__PACKAGE__->table("ausweis");
__PACKAGE__->columns_array(qw/id dtadd numid cmdid blkid blocked nick
                                 fio krov allerg neperenos polis medik comment/);

__PACKAGE__->link(command => 'Command', cmdid => 'id', {join_type => 'left'});
__PACKAGE__->link(blok => 'Blok', blkid => 'id', {join_type => 'left'});

sub create {
    my ($self, $new) = @_;
    
    if (ref($new) eq 'HASH') {
        $new->{dtadd} ||= \ 'NOW()';
    }
    
    return $self->SUPER::create($new);
}


1;
