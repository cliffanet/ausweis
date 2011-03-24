package C::Ausweis;

use strict;
use warnings;

##################################################
###     Основной список
###     Код модуля: 99
#############################################

sub _item {
    my $self = shift;
    my $command = delete $_[0]->{command};
    my $item = $self->ToHtml(shift, 1);
    my $id = $item->{id};
    
    $item->{command} = C::Command::_item($self, $command)
        if $command;
    
    if ($id) {
        # Ссылки
        $item->{href_info}       = $self->href($::disp{AusweisShow}, $item->{id}, 'info');
        #$item->{href_del}       = $self->href($::disp{AusweisDel}, $item->{id});
        #$item->{href_delete}    = $self->href($::disp{AusweisDel}, $item->{id});
    }
    
    return $item;
}


sub list {
    my ($self) = @_;

    return unless $self->rights_exists_event($::rAusweisList);
    
    $self->patt(TITLE => $text::titles{ausweis_list});
    $self->view_select->subtemplate("ausweis_list.tt");
    
    my $q = $self->req;
    my $f = {
        cmdid   => $q->param_dig('cmdid'),
        blkid   => $q->param_dig('blkid'),
        nick    => $q->param_str('nick'),
    };
    my $srch = {};
    $srch->{cmdid} = $f->{cmdid} if $f->{cmdid};
    $srch->{blkid} = $f->{blkid} if $f->{blkid};
    if ($f->{nick}) {
        $f->{nick} =~ s/%/\\%/g;
        $srch->{nick} = { LIKE => "%$f->{nick}%" };
    }
    
    my $srch_url = 
        join('&',
            (map { $_.'='.Clib::Mould->ToUrl($f->{$_}) }
            grep { $f->{$_} } keys %$f));
    $srch_url ||= '';
    
    $self->d->{srch} = $self->ToHtml($f);
    
    
    $self->d->{sort}->{href_template} = sub {
        my $sort = shift;
        return $self->href($::disp{AusweisList})."?".
                join('&', $srch_url, "sort=$sort");
    };
    my $sort = $self->req->param_str('sort');

    $self->d->{pager}->{href} ||= sub {
        my $page = shift;
        return $self->href($::disp{AusweisList})."?".
            join('&', $srch_url, $sort?"sort=$sort":(), $page>1?"page=$page":());
    };
    my $page = $self->req->param_dig('page') || 1;
    
    $self->d->{list} = [
        map {
                my $item = _item($self, $_);
                $item;
        }
        $self->model('Ausweis')->search(
            $srch,
            {
                prefetch => [qw/command blok/],
                $self->sort($sort || 'nick'),
            },
            $self->pager($page, 100),
        )
    ] if $srch_url;
    $self->d->{list} ||= 0;
}


sub show {
    my ($self, $id, $type) = @_;

    return unless $self->rights_exists_event($::rAusweisInfo);
    
    $type = 'info' if !$type || ($type !~ /^(edit|info)$/);
    
    my ($rec) = (($self->d->{rec}) = 
        map { _item($self, $_) }
        $self->model('Ausweis')->search({ id => $id }, { prefetch => [qw/command blok/] }));
    $rec || return $self->state(-000105);
    
    $self->patt(TITLE => sprintf($text::titles{"ausweis_$type"}, $rec->{nick}));
    $self->view_select->subtemplate("ausweis_$type.tt");
    
}


1;
