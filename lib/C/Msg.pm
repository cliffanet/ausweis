package C::Msg;

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
}


1;
