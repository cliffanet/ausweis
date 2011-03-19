#!/usr/bin/perl
package MPMain;

use strict;
use warnings;

use FindBin::Real qw(Bin);
use lib Bin."/../lib";
$::pathRoot = Bin.'/..';

use base 'Clib::HTTP::MP';

require "$::pathRoot/lib/InitMain.pm";

1;
