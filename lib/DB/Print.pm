package DB::Print;

use strict;
use warnings;

use base 'Clib::DBIC';

__PACKAGE__->table("print_party");
__PACKAGE__->columns_array(qw/id dtadd regen status/);

sub create {
    my ($self, $new) = @_;
    
    if (ref($new) eq 'HASH') {
        $new->{dtadd} ||= \ 'NOW()';
        $new->{status} ||= 'A';
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
