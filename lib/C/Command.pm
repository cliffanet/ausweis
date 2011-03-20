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


sub list {
    my ($self) = @_;

    return unless $self->rights_exists_event($::rCommandList);
    
    $self->patt(TITLE => $text::titles{command_list});
    $self->view_select->subtemplate("command_list.tt");
    
    my $cmd = $self->d->{cmd};
    
    $self->d->{sort}->{href_template} = $self->href($::disp{CommandList})."?sort=%s";
    my $sort = $self->req->param_str('sort');
    
    $cmd->{list} = [
        map { 
                my $item = _item($self, $_);
                $item;
        }
        $self->model('Command')->search(
            { },
            { 
                order_by => $self->sort($sort || 'name'),
            }
        )
    ];
}


1;
