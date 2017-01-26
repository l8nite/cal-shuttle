package Swat::Application;
use base qw(Swat::Controller Swat::Interface::Param);

# Copyright (C) 2004 Shaun Guth
#
# This program is free software; you can redistribute it and/or modify
# it under the same terms as perl itself

# Swat::Application implements the framework for a CGI application
# based around Swat::Controller, Swat::CGI, Swat::Template::Stack, 
# and Swat::Session

use 5.006;
use strict;
use warnings;


use Swat::CGI;
use Swat::Template::Stack;
#use Swat::Session;


# --------------------------------------------------------------------------- #
# Swat::Controller overrides

# called just before the instance script gets our object instance
# arg0: a filename to initialize the configuration from
sub controller_initialize
{
	my $self = shift;
	my $file = shift;

	# read configuration
	$self->application_load_configuration( $file );

	# initialize template stack
	$self->application_initialize_template_stack();

	return 1;
}

# called prior to a runmode being executed
sub controller_prerun { }

# called after a runmode is executed, but before we output
sub controller_postrun { }

# called before our instance is destroyed
sub controller_teardown { }

# called to retrieve our Swat::CGI object
sub controller_fetch_qobj
{
	return (shift)->{'_qobj'} ||= Swat::CGI->new();
}

# called with the return value of a runmode, note that this is different
# than the 'output' subroutine below, which actually generates the content
sub controller_output
{
	my $self = shift;

	$self->application_print_http_headers();

	print "@_";
}



# --------------------------------------------------------------------------- #
# Configuration

#set/get configuration values
sub application_configuration
{
	my $self = shift;
	my $data = $self->{'__configuration'} ||= {};

	# set flattened hash (list) of key/value pairs
	if( @_ > 1 )
	{
		die "Element list must be even" unless @_ % 2 == 0;
		%$data = (%$data, @_);
	}
	elsif( @_ == 1 )
	{
		# Maybe they want us to set a HASHREF
		if( ref $_[0] eq 'HASH' ) 
		{
			%$data = (%$data,%{$_[0]});
		}
		# They want us to give them the value for a key
		else
		{
			return $data->{$_[0]};
		}
	}

	return keys %$data;
}


# reads a configuration file and sets our configuration data
sub application_load_configuration
{
	my $self = shift;
	my $file = shift;

	if( !defined($file) || $file eq "" )
	{
		warn "No configuration file specified...\n";
		return -1;
	}

	unless( -s $file && -r $file )
	{
		warn "'$file' doesn't exist, isn't readable, or has 0 size.\n";
		return -1;
	}

	open( my $config_fh, '<', $file )
		or die "Unable to open '$file': $!";

	my $configuration = {};

	foreach my $line ( grep {!/^\s*#/} <$config_fh> )
	{
		chomp $line;
		next unless $line =~ /[^\s]/;

		# parse out a simple key=value, key: value, or key\tvalue
		my ($k,$v) = $line =~ /^\s*(.*?)\s*[=:\t]\s*(.*?)\s*;?\s*$/;

		# trim whitespace on key
		$k =~ s/^\s*|\s*$//g;

		# grab quoted data
		if( $v =~ /^\s*["'](.*?)['"]\s*(?:#.*)?;?$/ )
		{
			$v = $1;
		} 
		else
		{
			# trim whitespace on value
			$v =~ s/^\s*|\s*$//g;
		}

		$configuration->{$k} = $v;
	}

	close( $config_fh );

	$self->application_configuration( $configuration );

	return 1;
}



# --------------------------------------------------------------------------- #
# Swat::Template::Stack interface

# set/get the template stack
sub application_template_stack
{
	my $self = shift;

	if( @_ )
	{
		$self->{'__template_stack'} = shift;
	}

	return $self->{'__template_stack'};
}

# initialize template stack (default is just to create a new one)
sub application_initialize_template_stack
{
	my $self = shift;
	
	# all configuration keys 'template_*' are passed to the Template
	# constructor after transforming to uppercase
	my %template_config = 
		map  { 
			my $val = $self->application_configuration($_);
			my $key = $_;
			   $key =~ s/^template_(.*)$/\U$1/;
			( $key, $val );
		} 
		grep { m/^template_/ } $self->application_configuration();

	my $tstk = Swat::Template::Stack->new( \%template_config );

	# save for later
	$self->application_template_stack( $tstk );
}



# --------------------------------------------------------------------------- #
# HTTP/CGI related 

# to maintain consistency, this is provided for subclasses to use instead of
# the controller_fetch_qobj method
sub application_query_object 
{
	my $self = shift;
	return $self->controller_fetch_qobj(@_);
}


# sets the flattened hash, hashref, or arrayref of headers and their values
# gets the stored hash of headers
sub application_http_headers
{
	my $self = shift;
	my $hash = $self->{'__http_headers'} ||= {};

	if( @_ )
	{
		my %data = ref($_[0]) eq 'HASH' ? %{$_[0]} :
			   ref($_[0]) eq 'ARRAY'? map{$_=>$_} @{$_[0]} : (@_);
		%{ $hash } = ( %{ $hash }, %data );
	}

	return $hash;
}


# formats and returns the headers we've stored according to the http 1.1 RFC
sub application_get_http_headers
{
	my $self = shift;

	my @order = qw(
	Cache-Control Connection Date Pragma Trailer Transfer-Encoding Upgrade
	Via Warning

	Accept Accept-Charset Accept-Encoding Accept-Language
	Authorization Expect From Host

	If-Match If-Modified-Since If-None-Match If-Range If-Unmodified-Since
	Max-Forwards Proxy-Authorization Range Referer TE User-Agent

	Accept-Ranges Age ETag Location Proxy-Authenticate Retry-After Server
	Vary WWW-Authenticate

	Allow Content-Encoding Content-Language Content-Length Content-Location
	Content-MD5 Content-Range Content-Type Expires Last-Modified
	);

	my $headers = $self->{'__http_headers'};
	$headers->{'content-type'} ||= 'text/html'; # default

	my @output;
	my @names = map { $_ if exists $headers->{"\L$_"} } @order;

	foreach my $name ( @names ) 
	{
		my $value = $headers->{lc($name)} || next;
		push( @output, "$name: $value" );
	}

	return @output;
}


# prints out the http headers
sub application_print_http_headers
{
	my $self = shift;
	my @headers = $self->application_get_http_headers();

	local $" = "\n";
	print "@headers\n\n";
}



1; # Beam me up!


