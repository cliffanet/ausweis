package C::Misc;

use strict;
use warnings;

##################################################33

sub default {
    my ($self) = @_;
    return if $self->d->{denied};
    $self->view_select->subtemplate("default.tt");
}

1;
