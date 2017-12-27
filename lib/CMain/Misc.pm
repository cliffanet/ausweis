package CMain::Misc;

use strict;
use warnings;

##################################################33

sub default {
    my ($self) = @_;

    if ($self->rcheck('ausweis_list')) {
        $self->forward('ausweis/list');
    }
    elsif ($self->rcheck('command_info')) {
        $self->forward('command/my');
    }
}

sub login_er {
    my ($self, $login, $sub_state) = @_;
    $self->Clib::Plugin::Authenticate::Controller::login_form();
    $self->d->{auth_failed} = $sub_state || -1;
}


sub password_change_ok {
    my ($self, $login) = @_;
    if (my $uid = $self->session->{uid}) {
        $self->model('UserSession')->update({ state => 10300, uid => 0 }, { uid => $uid });
    }
    $self->redirect($self->href());
}


1;
