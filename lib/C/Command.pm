package C::Command;

use strict;
use warnings;

##################################################
###     Ñïèñîê êîìàíä
###     Êîä ìîäóëÿ: 98
#############################################

sub _item {
    my $self = shift;
    my $item = $self->ToHtml(shift, 1);
    my $id = $item->{id};
    
    if ($id) {
        # Ññûëêè
        #$item->{href_del}       = $self->href($::disp{CommandDel}, $item->{id});
        #$item->{href_delete}    = $self->href($::disp{CommandDel}, $item->{id});
    }
    
    return $item;
}

sub search {
    my ($self, $srch, $order) = @_;
    
    return [
        map { 
                my $item = _item($self, $_);
                $item;
        }
        $self->model('Command')->search(
            $srch,
            { 
                order_by => $order,
            }
        )
    ];
}


sub list {
    my ($self) = @_;

    return unless $self->rights_exists_event($::rCommandList);
    
    $self->patt(TITLE => $text::titles{command_list});
    $self->view_select->subtemplate("command_list.tt");
    
    my $cmd = $self->d->{cmd};
    
    my $q = $self->req;
    my $f = {
        cmdid   => $q->param_dig('cmdid'),
        blkid   => $q->param_dig('blkid'),
        name    => $q->param_str('name'),
    };
    my $srch = {};
    $srch->{id} = $f->{cmdid} if $f->{cmdid};
    $srch->{blkid} = $f->{blkid} if $f->{blkid};
    if ($f->{name}) {
        $f->{name} =~ s/%/%%/g;
        $srch->{name} = { LIKE => "%$f->{name}%" };
    }
    
    my $srch_url = 
        join('&',
            (map { $_.'='.Clib::Mould->ToUrl($f->{$_}) }
            grep { $f->{$_} } keys %$f));
    $srch_url ||= '';
    
    $self->d->{srch} = $self->ToHtml($f);
    
    
    
    $self->d->{sort}->{href_template} = sub {
        my $sort = shift;
        return $self->href($::disp{CommandList})."?".
                join('&', $srch_url, "sort=$sort");
    };
    my $sort = $self->req->param_str('sort');

    $self->d->{pager}->{href} ||= sub {
        my $page = shift;
        return $self->href($::disp{CommandList})."?".
            join('&', $srch_url, $sort?"sort=$sort":(), $page>1?"page=$page":());
    };
    my $page = $self->req->param_dig('page') || 1;
    
    $self->d->{list} = [
        map {
                my $item = _item($self, $_);
                $item;
        }
        $self->model('Command')->search(
            $srch,
            {
                prefetch => 'blok',
                $self->sort($sort || 'name'),
            },
            $self->pager($page, 100),
        )
    ] if $srch_url;
    $self->d->{list} ||= 0;
}


1;
