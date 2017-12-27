#!/usr/bin/perl
package MPKpp;

use strict;
use warnings;

#BEGIN {
#    $::pathRoot = $0;
#    $::pathRoot =~ s/\/+/\//g;
#    $::pathRoot =~ s/[^\/]+$//;
#    if ($::pathRoot !~ s/\/[^\/]+\/$//) {
#        $::pathRoot .= '..';
#    }
#};

#use lib "$::pathRoot/lib";
use base 'Clib::HTTP::MP';

require "$::pathRoot/lib/InitKpp.pm";

1;
