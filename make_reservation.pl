#!/usr/bin/perl
use warnings;
use strict;

use lib 'ivr/modules';
use CalShuttle::RSystem;


sub main
{
	my $application = CalShuttle::RSystem->new();

	# force the run-mode
	$application->application_query_object()->param( 
	   	'rm' => 'make_reservation'
	);

	$application->controller_run();
}


exit(&main(@ARGV));
