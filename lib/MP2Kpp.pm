#!/usr/bin/perl
package MP2Kpp;

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
use base 'Clib::HTTP::MP2';

require "$::pathRoot/lib/InitKpp.pm";

1;
