package Func;

use strict;
use warnings;

####################################################

sub _CachDir {
    my ($type, $id) = @_;
    $id || return;
    $::dirFiles || return;
    $type ||= 'unknown';
    
    my @list = ($::dirFiles, $type);
    if (($type eq 'command') || ($type eq 'blok')) {
        $id = sprintf("%04d", $id);
        push @list, $id;
    } else {
        $id = sprintf("%06d", $id);
        push @list, $id =~ /^(\d+)(\d\d)(\d\d)$/ ? ($1, $2, $3) : $id;
    }
        
    return @list;
}

sub CachDir {
    my ($type, $id) = @_;
    return join('/', _CachDir($type, $id));
}

sub MakeCachDir {
    my ($type, $id) = @_;

    my $dir;
    foreach my $di (_CachDir($type, $id)) {    
        $dir .= "/" if $dir;
        $dir .= $di;
        if (!(-d $dir)) {
            mkdir($dir) || return;
        }
    }
        
    return 1;
}


####################################################

1;
