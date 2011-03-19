#!/usr/bin/perl
package MP2Main;

use strict;
use warnings;

use FindBin::Real qw(Bin);
use lib Bin."/../lib";
$::pathRoot = Bin.'/..';

use base 'Clib::HTTP::MP2';

require "$::pathRoot/lib/InitMain.pm";

1;
