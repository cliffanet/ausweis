package V::Main;

use strict;
use base qw/
                Clib::View::Mould
            /;

=head2
    Стандартная инициализация
=cut
__PACKAGE__->config(
    mould       => "base",
    FilesPath   => "$::pathRoot/moulds",
);


sub default {
    my ($self) = @_;
    my $r = $self->r;
    my $d = $r->d;
    
    my $patt = {
    };
    
    return $self->Parse(mould => "default", pattlist => $patt);
}


1;
