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
    nick        => { type => '!s', handler => \&hnd_nick },
    fio         => { type => '!s', handler => \&hnd_fio },
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
__PACKAGE__->link(print => 'PrintAusweis', id => 'ausid', {join_type => 'left'});
__PACKAGE__->link(event => 'EventAusweis', id => 'ausid', {join_type => 'left'});

sub create {
    my ($self, $new) = @_;
    
    if (ref($new) eq 'HASH') {
        $new->{dtadd} ||= \ 'NOW()';
        $new->{numid} ||= $self->gen_numid || return;
        if (!$new->{regen}) {
            $new->{regen} = 0;
            $new->{regen} = $new->{regen} | (1<<($::regen{code}-1)) if $::regen{code};
            $new->{regen} = $new->{regen} | (1<<($::regen{photo}-1)) if $::regen{photo} && $new->{photo};
            $new->{regen} = $new->{regen} | (1<<($::regen{print_img}-1)) if $::regen{print_img};
            $new->{regen} = $new->{regen} | (1<<($::regen{print_pdf}-1)) if $::regen{print_pdf};
        }
    }
    
    return $self->SUPER::create($new);
}

sub gen_numid {
    my ($self, $where, %args) = @_;
    my $numid = $self->max_value('numid', $where, %args) || return;
    
    return $numid + 1;
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

sub search_nick_fio_full {
    my ($self, $text, $prec, %args) = @_;
    
    $args{sql} = 
        "SELECT *, ? as `srch`, MATCH(`nick`, `fio`) AGAINST(`srch`) as `prec`".
        " FROM `ausweis`".
        " WHERE `blocked` = ?".
        " AND MATCH(`nick`, `fio`) AGAINST(?)";
    $args{params} = [0, $text, $text];
    
    if ($prec) {
        $args{sql} .= " > ?";
        push @{ $args{params} }, $prec;
    }
    
    if ($args{func}) {
        return $self->select_func(%args);
    } else {
        my @list = ();
        $self->select_func(%args, func => sub { push @list, {@_} });
        return @list;
    }
}


#######################################################################
sub hnd_nick {
    my ($self, $param, $index, $value, $ptr) = @_;
    
    my $rec = $self->d->{rec};
    my %id = $rec ? (id => { '!=' => $rec->{id}}) : ();
    
    my $blocked = $self->d->{is_blocked} ? 1 : 0;
    my $item = $self->model('Ausweis')->search({ nick => $value, blocked => $blocked, cmdid => $self->d->{cmdid}, %id });
    if ($item) {
        return $blocked ? 22 : 21;
    }
    return 0;
}

sub hnd_fio {
    my ($self, $param, $index, $value, $ptr) = @_;
    
    my $rec = $self->d->{rec};
    my %id = $rec ? (id => { '!=' => $rec->{id}}) : ();
    
    if (!$self->d->{is_blocked}) {
        my $item = $self->model('Ausweis')->search({ fio => $value, blocked => 0, cmdid => $self->d->{cmdid}, %id });
        return 23 if $item;
    }
    
    return 0;
}



1;
