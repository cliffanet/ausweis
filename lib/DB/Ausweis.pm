package DB::Ausweis;

use strict;
use warnings;

use base 'Clib::DBIC';

__PACKAGE__->table("ausweis");
__PACKAGE__->columns_array(qw/id dtadd numid cmdid blkid blocked regen nick
                                 fio krov allerg neperenos polis medik comment photo/);

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
