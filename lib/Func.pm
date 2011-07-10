package Func;

use strict;
use warnings;

####################################################

sub UserDir {
    my $id = shift;
    $id || return;
    $::dirFiles || return;
    
    $id = sprintf("%06d", $id);
    my ($d1, $d2, $d3) = ($1, $2, $3)
        if $id =~ /^(\d+)(\d\d)(\d\d)$/;
        
    return "$::dirFiles/ausweis/$d1/$d2/$d3";
}

sub MakeUserDir {
    my $id = shift;
    $id || return;
    $::dirFiles || return;
    
    $id = sprintf("%06d", $id);
    my ($d1, $d2, $d3) = ($1, $2, $3)
        if $id =~ /^(\d+)(\d\d)(\d\d)$/;
        
    if (!(-d $::dirFiles)) {
        mkdir($::dirFiles) || return;
    }
    if (!(-d "$::dirFiles/ausweis")) {
        mkdir("$::dirFiles/ausweis") || return;
    }
    if (!(-d "$::dirFiles/ausweis/$d1")) {
        mkdir("$::dirFiles/ausweis/$d1") || return;
    }
    if (!(-d "$::dirFiles/ausweis/$d1/$d2")) {
        mkdir("$::dirFiles/ausweis/$d1/$d2") || return;
    }
    if (!(-d "$::dirFiles/ausweis/$d1/$d2/$d3")) {
        mkdir("$::dirFiles/ausweis/$d1/$d2/$d3") || return;
    }
        
    return 1;
}


####################################################

1;
