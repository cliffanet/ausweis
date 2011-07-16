package DB::Ausweis;

use strict;
use warnings;

use base 'Clib::DBIC';

__PACKAGE__->table("ausweis");
__PACKAGE__->columns_hash(
    id          => { skip => 1 },
    dtadd       => { skip => 1 },
    numid       => { skip => 1 },
    cmdid       => { type => '!d', handler => \&DB::Command::hnd_cmdid },
    blkid       => { skip => 1 },
    blocked     => 'b',
    regen       => { skip => 1 },
    nick        => '!s',
    fio         => 's',
    krov        => 's',
    allerg      => 's',
    neperenos   => 's',
    polis       => 's',
    medik       => 's',
    comment     => 's',
    photo       => { skip => 1 },
);

__PACKAGE__->link(command => 'Command', cmdid => 'id', {join_type => 'left'});
__PACKAGE__->link(blok => 'Blok', blkid => 'id', {join_type => 'left'});

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

1;
