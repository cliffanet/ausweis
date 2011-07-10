package Pdf;

use strict;
use warnings;

##################################################################
######
######  Преподготовка печатной формы - pdf
######

sub Ausweis {
    my ($self, $rec, $type) = @_;

    if (ref($rec) ne 'HASH') {
        ($rec) =
            $self->model('Ausweis')->search({ id => $rec }, { prefetch => [qw/command blok/] });
        $rec || return;
    }
    
}




####################################################

1;
