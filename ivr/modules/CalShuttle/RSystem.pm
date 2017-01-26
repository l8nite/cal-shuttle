package CalShuttle::RSystem;
use base qw(Swat::Application);
use warnings;
use strict;


# called before anything else
sub controller_initialize
{
	my $self = shift;

	# initialize our controller instance and load configuration
	$self->SUPER::controller_initialize(
	'/var/www/vhosts/speedy.l8nite.net/cal-shuttle/data/rsystem.conf'
	);

	# set up our runmodes
	$self->controller_modes(
		'get_user_info'    => 'rm_get_user_info',
		'make_reservation' => 'rm_make_reservation',
		'AUTOLOAD'         => 'rm_invalid_runmode',
	);

	$self->application_http_headers( 'content-type' => 'text/plain' );
}


# a run-mode which handles the case that an invalid or no runmode was specified
sub rm_invalid_runmode
{
	my $self = shift;
	my $mode = $self->controller_runmode();

	$self->_result( -1, "Invalid Runmode '$mode'" );

	return $self->application_template_stack()->finish();
}


# a run-mode which given an ANI (automated number identification) will validate
# and return in an XML snippet, the userid associated with it.
sub rm_get_user_info
{
	my $self = shift;
	my $tstk = $self->application_template_stack();
	my $qobj = $self->application_query_object();

	my $ani = $qobj->param( 'ani' );

	# did they specify our ani as a parameter?
	if( !defined($ani) )
	{	
		my %result = (
		'code' => -1,
		'text' => "Must pass ANI",
		);

		$tstk->push( 'result.xml.ttml', 'result' => \%result );

		return $tstk->finish();
	}

	# ensure the ani parameter is valid (10-digits only)
	if( length($ani) != 10 || $ani =~ /[^0-9]/ )
	{
		my %result = (
		'code' => -1,
		'text' => "Invalid ANI received",
		);

		$tstk->push( 'result.xml.ttml', 'result' => \%result );

		return $tstk->finish();
	}


	# fetch user info 
	my $user;
	eval { $user = $self->_fetch_user_info( $ani ); };

	# any errors?
	if( $@ )
	{
		my %result = (
		'code' => -1,
		'text' => "Error retrieving user data",
		);

		$tstk->push( 'result.xml.ttml', 'result' => \%result );

		return $tstk->finish();
	}

	# valid user found?
	if( defined($user) && ref($user) eq 'HASH' )
	{
		my %result = (
		'code' => 0,
		'text' => "User Found",
		);

		$tstk->push( 'result.xml.ttml', 'result' => \%result );
		$tstk->pushp( 'user.xml.ttml', 'contents', 'user' => $user );

		return $tstk->finish();
	}
	else
	{
		my %result = (
		'code' => 1,
		'text' => "User Not Found",
		);

		$tstk->push( 'result.xml.ttml', 'result' => \%result );

		return $tstk->finish();
	}

	return 1;
}


# given an ANI, will read a CSV text file in the format "aaaaaaaaaa,uuuuuuuu"
# where the first column is the ANI and second column is the userid
sub _fetch_user_info 
{
	my $self = shift;
	my $ani  = shift;
	my $udat = $self->application_configuration( 'user_data_file' );

	open( my $fh, '<', $udat )
		or die "Unable to open file for reading: '$udat'\n";
	my ($data) = grep { /^$ani,\d+$/ } <$fh>;
	close( $fh );

	if( defined($data) )
	{
		my ($uid) = (split(/[,\n]/,$data))[1];
		return { 'ani' => $ani, 'id' => $uid };
	}

	return undef;
}



# given a userid, airport, departure date and time - will validate the info
# against our reservations and return an XML snippet with the pickup info.
sub rm_make_reservation
{
	my $self = shift;
	my $tstk = $self->application_template_stack();
	my $qobj = $self->application_query_object();

	my $user_id = $qobj->param( 'id' );
	my $airport = $qobj->param( 'airport' );
	my $depdate = $qobj->param( 'date' );
	my $deptime = $qobj->param( 'time' );

	# any missing parameters is cause for instant failure
	if( !defined($user_id) || !defined($airport) ||
		!defined($depdate) || !defined($deptime) )
	{
		$self->_result(-1, "Must pass id, airport, date, and time parameters");
		return $tstk->finish();
	}

	# validate the user id parameter
	elsif( length($user_id) != 8 || $user_id =~ /[^0-9]/ )
	{
		$self->_result( -1, "Invalid userid received" );
		return $tstk->finish();
	}

	# validate the airport parameter
	elsif( length($airport) != 3 || !(grep { /SFO|SJC|OAK/ } ($airport)) )
	{
		$self->_result(-1, "Invalid airport! Only SFO, SJC, and OAK allowed.");
		return $tstk->finish();
	}

	# validate the date parameter
	elsif( length($depdate) != 8 || $depdate !~ m{^[01]\d/[0-3]\d/\d\d$} )
	{
		$self->_result( -1, "Invalid date, format must be mm/dd/yy" );
		return $tstk->finish();
	}

	# validate the time parameter
	elsif( length($deptime) != 5 || $deptime !~ m{^[0-2]\d:[0-6]\d$} )
	{
		$self->_result( -1, "Invalid time, format must be hh:mm" );
		return $tstk->finish();
	}

	
	# fetch reservation info 
	my $resv;
	eval { 
		my @params = ( $user_id, $airport, $depdate, $deptime );
		$resv = $self->_fetch_reservation( @params );
	};

	# any errors?
	if( $@ )
	{
		$self->_result( -1, "Error retrieving reservation data" );
		return $tstk->finish();
	}

	# valid entry found?
	if( defined($resv) && ref($resv) eq 'HASH' )
	{
		$self->_result( 0, "Reservation Successful" );

		$tstk->pushp('reservation.xml.ttml','contents','reservation' => $resv);

		return $tstk->finish();
	}
	else
	{
		$self->_result( 1, "Reservation not found" );
		return $tstk->finish();
	}
}


# reads a CSV file and tries to match userid, airport, and departure date/time
# to a reservation line.  Returns a hash of the key/values if so
sub _fetch_reservation
{
	my ($self,$id,$ap,$dd,$dt) = @_;

	my $rdat = $self->application_configuration( 'reservation_data_file' );

	open( my $fh, '<', $rdat )
		or die "Unable to open file for reading: '$rdat'\n";
	my ($data) = grep { /^$id,$ap,$dd,$dt,/ } <$fh>;
	close( $fh );

	if( defined($data) )
	{
		my @data = split(/[,\n]/,$data);

		my %resv = (
			'airport'    => $data[1],
			'flightdate' => $data[2],
			'flighttime' => $data[3],
			'id'         => $data[4],
			'pickupdate' => $data[5],
			'pickuptime' => $data[6],
			'fare'       => $data[7],
		);

		return \%resv;
	}

	return undef;
}


# sticks the result.xml.ttml template on the stack with the code and text set
sub _result
{
	my ($self,$code,$text) = @_;

	$self->application_template_stack()->push(
		'result.xml.ttml',
		'result' => { 'code' => $code, 'text' => $text },
	);
}



1;


__END__
