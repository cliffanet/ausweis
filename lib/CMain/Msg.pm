package CMain::Msg;

use strict;
use warnings;

use Encode '_utf8_on', 'encode';

##################################################
###     Система оповещения
###     Код модуля: 93
#############################################

sub _root :
    ReturnPatt
{
    my ($self) = @_;

    $self->view_rcheck('msg_read') || return;
    $self->template("msg", 'CONTENT_result');
    
    my @qsrch = ();
    my $srch = { uid => $self->user->{id} };
    my $s = $self->req->param_str('srch');
    _utf8_on($s);
    push @qsrch, { f => 'srch', val => $s };
    if (my $msg = $s) {
        $msg =~ s/([%_])/\\$1/g;
        $msg =~ s/\*/%/g;
        $msg =~ s/\?/_/g;
        $msg = "%$msg" if $msg !~ /^%/;
        $msg .= "%" if $msg !~ /%$/;
        $srch->{txt} = { LIKE => $msg };
    }

    
    my ($count, $countall);
    my @list = $self->model('Msg')->search(
            $srch,
            {
                order_by => '-dtadd',
            },
            pager => {
                onpage => 100,
                handler => sub {
                    my %p = @_;
                    $count = $p{count};
                    $countall = $p{countall};
                },
            },
        );
    
    my @noreaded =
        map { $_->{id} }
        grep { !$_->{readed} }
        @list;
    $self->model('Msg')->update({ readed => 1 }, { id => \@noreaded }) if @noreaded;
    
    return
        srch => $s,
        qsrch => $self->qsrch(@qsrch),
        list => \@list,
        count   => $count,
        countall=> $countall,
        
        email => $self->user->{email},
}


sub email :
    ReturnOperation
{
    my ($self) = @_;
    
    $self->rcheck('msg_cfg') || return $self->rdenied;
    $self->d->{read_only} && return $self->cantedit();
    
    my %upd = ();
    my %err = ();
    my $q = $self->req;
    
    foreach my $p (qw/email/) {
        _utf8_on($upd{$p} = $q->param_str($p))
            if defined $q->param($p);
    }
    
    # Проверка данных
    if (exists($upd{email})) {
        if ($upd{email} && ($upd{email} !~ /^[a-zA-Z_0-9][a-zA-Z_0-9\-\.]*\@[a-zA-Z0-9\_\-]+\.[a-zA-Z0-9]{1,4}$/)) {
            $err{email} = 2;
        }
    }
    else {
        $err{email} = 1;
    }
    
    # Ошибки заполнения формы
    my @fpar = (qw/email/);
    if (%err) {
        return (error => 000101, pref => 'msg', fpar => \@fpar, ferr => \%err);
    }
    
    # Поля, которые не изменились
    delete($upd{$_}) foreach grep { $self->user->{$_} eq $upd{$_} } keys %upd;
    
    %upd || return (error => 000106, href => '');
    
    # Сохраняем
    $self->model('UserList')->update(\%upd, { id => $self->user->{id} })
        || return (error => 000104, pref => 'msg', fpar => \@fpar, ferr => \%err);
    
    # Статус с редиректом
    return (ok => 930100, href => '');
}



1;
