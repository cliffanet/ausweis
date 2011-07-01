package V::File;

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

    if (!$d->{error} && $d->{file} && !(-f $d->{file})) {
        $d->{error} = "$d->{file}: file not found";
    }
    if ($d->{error} || !$d->{file}) {
        $self->r->res->headers('Content-type' => 'text/plain');
        $d->{error} ||= 'unknown';
        $self->r->res->body( "ERROR: $d->{error}\n" );
        $self->r->error("V::File ERROR: $d->{error}");
    }
    else {
        $self->r->res->headers('Content-type' => $d->{type} || 'application/data');
        $self->r->res->headers('Content-Disposition' => "attachment; filename=$d->{filename}")
            if $d->{filename};
            
            local *FHF;
            $self->r->debug("V::File Get file: $d->{file}");
            if (!open(FHF, $d->{file})) {
                $self->r->error("V::File Can't open file ($d->{file}): $!");
                return;
            }
            local $/ = undef;
            my $data = <FHF>;
            close FHF;
            
        $self->r->res->body( \$data );
    }
}

sub runtime { shift->{_runtime}; }
sub r { shift->{_runtime}; }

=head2 clear
    ќчищаем все переменные дл€ следующего запроса
=cut
sub clear {
    my $self = shift;
    undef $self->r->d->{data};
}



1;
