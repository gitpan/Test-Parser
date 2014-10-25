use strict;
my @scripts;

use Test::More tests => 5;

my $logfile = $0;
$logfile =~ s/t$/log/;

ok ( -e "./$logfile", "Verifying existance of $logfile")
   or diag("No log file found for '$0'");

use Test::Parser::LTP;

my $parser = new Test::Parser::LTP;
$parser->parse($logfile);

ok ($parser->num_executed() == 34, "Executed count");
ok ($parser->num_passed()   == 9,  "Passed count");
ok ($parser->num_failed()   == 4,  "Failed count");
ok ($parser->num_skipped()  == 4,  "Skipped count");




