# $Id: 00_initialize.t.tt2,v 1.1 2004/09/16 22:46:42 bryce Exp $

use strict;
use Test::More tests => 2;

BEGIN { use_ok('Test::Parser'); }
BEGIN { use_ok('Test::Parser::KernelBuild'); }

diag( "Testing Test::Parser $Test::Parser::VERSION" );



