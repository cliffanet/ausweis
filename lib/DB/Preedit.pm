package DB::Preedit;

use strict;
use warnings;

use base 'Clib::DBIC';

__PACKAGE__->table("preedit");
__PACKAGE__->columns_array(qw/id dtadd tbl op recid modered uid ip/);

__PACKAGE__->link( field => 'PreeditField', id => 'eid', {join_type => 'left'} );
__PACKAGE__->link( user   => 'UserList', uid => 'id', {join_type => 'left'} );

sub create {
    my ($self, $new) = @_;
    
    if (ref($new) eq 'HASH') {
        $new->{tbl} || return;
        $new->{op} || return;
        if (($new->{op} eq 'E') || ($new->{op} eq 'D')) {
            $new->{recid} || return;
        }
        $new->{dtadd} ||= \ 'NOW()';
        $new->{uid} ||= $self->r->user->{id}
            if $self->r && $self->r->can('user') && 
                $self->r->user && $self->r->user->{id} && $self->r->user->{rights};
        $new->{ip} ||= $ENV{REMOTE_ADDR} if $ENV{REMOTE_ADDR};
    }
    
    return $self->SUPER::create($new);
}

sub add {
    my ($self, %args) = @_;
    
    my $op      = $args{op} || return;
    my $fields  = delete($args{fields}) || delete($args{field});
    my $old     = delete($args{old}) || delete($args{fields_old}) || delete($args{field_old});
    
    # Проверка списка изменяемых полей
    if (($op eq 'C') || ($op eq 'D')) {
        $fields ||= $old;
        undef $old;
    }
    return '0E0' if !$fields || !(keys %$fields);
    my @fields;
    if ($op eq 'E') {
        return if !$old || !(keys %$old);
        my $count = 0;
        foreach my $f (keys %$fields) {
            my $value = $fields->{$f};
            $value = $$value if ref($value) eq 'SCALAR';
            my $o = exists($old->{$f}) ? $old->{$f} : undef;
            next if defined($o) && ($o eq $value);
            push @fields, $f;
        }
        return '0E0' if !@fields;
    }
    
    # Создание точки изменения
    $self->create(\%args) || return;
    my $id = $self->insertid;
    
    my $count = '0E0';
    
    # Изменение полей
    if ($fields) {
        my $ret = $self->schema->model('PreeditField')->add($id, $fields, $old) || return;
        $count = $ret;
    }
    
    # Удаяем предыдущие неотмодерированные одноименные поля
    if ($count && ($count > 0) && ($op eq 'E') && !$args{modered} && @fields) {
        my @p = $self->search(
            { 
                tbl     => $args{tbl},
                op      => 'E',
                recid   => $args{recid},
                modered => 0,
                'field.param' => \@fields,
                id      => { '!=' => $eid },
            } ,
            { prefetch => 'field' },
        );
        foreach my $p (@p) {
            $self->schema->model('PreeditField')->delete({ id => $p->{field}->{id} })
                || return;
        }
        @p = $self->search(
            { 
                tbl     => $args{tbl},
                op      => 'E',
                recid   => $args{recid},
                modered => 0,
                '`cnt`' => 0,
            } ,
            { 
                join => 'field',
                '+columns' => ['COUNT(*) as `cnt`'],
                group_by => 'id',
            },
        );
        foreach my $p (@p) {
            $self->schema->model('Preedit')->delete({ id => $p->{id} })
                || return;
        }
    }
    
    $count;
}

1;
