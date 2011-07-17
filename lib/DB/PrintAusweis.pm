package DB::PrintAusweis;

use strict;
use warnings;

use base 'Clib::DBIC';

__PACKAGE__->table("print_ausweis");
__PACKAGE__->columns_array(qw/id prnid ausid/);

sub create {
    my ($self, $new) = @_;
    
    if (ref($new) eq 'HASH') {
        $new->{prnid} || return;
        $new->{ausid} || return;
    }
    
    return $self->SUPER::create($new);
}


1;
