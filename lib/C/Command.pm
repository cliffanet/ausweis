package C::Command;

use strict;
use warnings;

##################################################
###     Список команд
###     Код модуля: 98
#############################################

sub _item {
    my $self = shift;
    my $item = $self->ToHtml(shift, 1);
    my $id = $item->{id};
    
    if ($id) {
        # Ссылки
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
    
    $self->d->{sort}->{href_template} = $self->href($::disp{CommandList})."?sort=%s";
    my $sort = $self->req->param_str('sort');
    
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
        $srch->{name} = { LIKE => $f->{name} };
    }
    
    $self->d->{srch} = $self->ToHtml($f);
    
    $self->d->{list} = (grep { $f->{$_} } keys %$f) ?
        search($self, $srch, $self->sort($sort || 'name')) :
        0;
}


1;
