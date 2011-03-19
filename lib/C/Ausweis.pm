package C::Ausweis;

use strict;
use warnings;

##################################################
###     Основной список
###     Код модуля: 99
#############################################

sub _item {
    my $self = shift;
    my $item = $self->ToHtml(shift, 1);
    my $id = $item->{id};
    
    if ($id) {
        # Ссылки
        #$item->{href_del}       = $self->href($::disp{AusweisDel}, $item->{id});
        #$item->{href_delete}    = $self->href($::disp{AusweisDel}, $item->{id});
    }
    
    return $item;
}


sub list {
    my ($self) = @_;

    return unless $self->rights_exists_event($::rAusweisView);
    
    $self->patt(TITLE => $text::titles{ausweis_list});
    $self->view_select->subtemplate("ausweis_list.tt");
    
    my $aus = $self->d->{aus};
    
    $self->d->{sort}->{href_template} = $self->href($::disp{AusweisList})."?sort=%s";
    my $sort = $self->req->param_str('sort');
    
    $aus->{list} = [
        map { 
                my $item = _item($self, $_);
                $item;
        }
        $self->model('Ausweis')->search(
            { },
            { 
                order_by => $self->sort($sort) || [qw/nick/],
            }
        )
    ];
}


1;
