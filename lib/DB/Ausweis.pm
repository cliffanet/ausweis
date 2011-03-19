package DB::Ausweis;

use strict;
use warnings;

use base 'Clib::DBIC';

__PACKAGE__->table("ausweis");
__PACKAGE__->columns_hash(
    id          => { skip => 1 },
    dtadd       => { skip => 1 },
    deleted     => { skip => 1 },
    name        => '!s',
    model       => '!s',
    ip          => { type => '!s',      handler => \&DB::Switch::hnd_ip_full,
                                        pattern => '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$' },
    isup        => { skip => 1 },
    inwork      => 'b',
    login       => 's',
    password    => 's',
    community   => 's',
    comment     => 's',
);

sub create {
    my ($self, $new) = @_;
    
    if (ref($new) eq 'HASH') {
        $new->{dtadd} ||= \ 'NOW()';
    }
    
    return $self->SUPER::create($new);
}


1;
