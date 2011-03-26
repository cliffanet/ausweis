package V::Image;

use strict;
use base qw/
        Clib::Component
    /;

=head2
    —тандартна€ инициализаци€
=cut
#__PACKAGE__->config(
#);


use Encode 'decode';

sub new {
    my ($class, $r) = @_;
    
    my $config = $class->Clib::Runtime::config();
    
    my $self = bless $config, $class;
    $self->{_runtime} = $r;
    $self->{_config} = { %$config };
    return $self;
}


sub render {
    my ($self) = @_;
    my $d = $self->r->d;

    if ($d->{error} || !$d->{img}) {
        $self->r->res->headers('Content-type' => 'text/plain');
        $d->{error} ||= 'unknown';
        $self->r->res->body( "ERROR: $d->{error}\n" );
    }
    else {
        $self->r->res->headers('Content-type' => 'image/png');
        $self->r->res->headers('Content-Disposition' => "attachment; filename=$d->{filename}")
            if $d->{filename};
            
        use Data::Dumper;
        $self->r->debug("IMG: $d->{img}");
        my $out;
        if (my $error = $d->{img}->Write(\$data, 'png:-')) {
            $self->r->error("Write PNG ERROR: $error");
        }
        else {
            $self->r->res->body( \$out );
        }
    }
}

sub runtime { shift->{_runtime}; }
sub r { shift->{_runtime}; }

=head2 clear
    ќчищаем все переменные дл€ следующего запроса
=cut
sub clear {
    my $self = shift;
    undef $self->d->{img};
}



1;
