package V::Image;

use strict;
use base qw/
        Clib::Component
    /;

=head2
    ����������� �������������
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
        $self->r->res->headers('Content-type' => 'image/gif');
        $self->r->res->headers('Content-Disposition' => "attachment; filename=$d->{filename}")
            if $d->{filename};
            
        $self->r->res->body( \$d->{img}->ImageToBlob( magick=>'GIF' ) );
    }
}

sub runtime { shift->{_runtime}; }
sub r { shift->{_runtime}; }

=head2 clear
    ������� ��� ���������� ��� ���������� �������
=cut
sub clear {
    my $self = shift;
    undef $self->d->{img};
}



1;
