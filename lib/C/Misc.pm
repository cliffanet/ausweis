package C::Misc;

use strict;
use warnings;

##################################################33

sub default {
    my ($self) = @_;
    return if $self->d->{denied};
    #$self->patt(TITLE => $text::titles{default});
    #$self->view_select->subtemplate("default.tt");
}


sub password_change_ok {
    my ($self, $login) = @_;
    if (my $uid = $self->session->{uid}) {
        $self->model('UserSession')->update({ state => 10300, uid => 0 }, { uid => $uid });
    }
    $self->redirect($self->href());
}


1;
