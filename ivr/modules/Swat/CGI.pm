package Swat::CGI;
use base qw(Swat::Interface::Param);

# Copyright (C) 2004 Shaun Guth
#
# This program is free software; you can redistribute it and/or modify
# it under the same terms as perl itself.

# Mostly lifted and reworked from CGI::Simple and CGI.pm
# Give credit to the authors of those fine modules instead :-)

use 5.006;
use strict;
use warnings;


# construct0r
sub new 
{
	my $proto = shift;
	my $class = ref($proto) || $proto;
	my $self  = bless( {}, $class );

	$self->initialize_cookie();
	$self->initialize_params();

	return $self;
}


# allow us to access cookie data in the same manner as query data
sub cookie
{
	my $self = shift;
	$self->_param( '__cookies', @_ );
}


# read in the http cookies
sub initialize_cookie
{
	my $self  = shift;
	my $dough = $ENV{'HTTP_COOKIE'} || $ENV{'COOKIE'};
	return () unless $dough;

	my %results;
	my @pairs = split "; ?", $dough;

	foreach my $pair (@pairs)
	{
		$pair =~ s/^\s+|\s+$//;
		my ( $p, $v ) = split '=', $pair;
		next unless defined $v;
		($p, @_) = $self->url_decode( $p, split(/[&;]/,$v) );
		$self->cookie( $p => $#_ ? \@_ : $_[0] );
	}
}



# reads the CGI environment and parses the query string into a hash
sub initialize_params
{
	my $self = shift;

	my $type    = $ENV{'CONTENT_TYPE'}   || 'No CONTENT_TYPE received';
	my $length  = $ENV{'CONTENT_LENGTH'} || 0;
	my $method  = $ENV{'REQUEST_METHOD'} || 'No REQUEST_METHOD received';

	my $data = '';

	if( $method eq 'POST') 
	{
		if( $length ) 
		{
			if( defined $length && $length > 0 )
			{
				read( STDIN, $data, $length );
			}

			unless( $length == length $data ) 
			{
				die "Bad read! ".(length $data)."/$length\n";
			}
		}
	}
	elsif ( $method eq 'GET' or $method eq 'HEAD' ) 
	{
		$data = $ENV{'QUERY_STRING'} ||
			$ENV{'REDIRECT_QUERY_STRING'} ||
			'';
	}

	unless ( defined($data) ) 
	{
		die "No data received via method: $method, type: $type";
	}


	my @pairs = split /[&;]/, $data;

	for my $pair (@pairs)
	{
		my ( $param, $value ) = split '=', $pair;
		next unless defined $param;

		$value = '' unless defined $value;
		($param,$value) = $self->url_decode($param,$value);
		$param =~ tr/\000//d; $value =~ tr/\000//d;

		$self->param( $param => $value );
	}
}


# some helper functions
sub url_decode
{
	my $self = shift;
	return () unless scalar(@_);

	map {
		tr/+/ /; 
		s/%([a-fA-F0-9]{2})/ pack "C", hex $1 /eg;
	} @_;

	return @_;
}


sub url_encode
{
	my ($self,$encd) = (shift, shift || return ());

	$encd =~ s/([^A-Za-z0-9\-_.!~*'() ])/ uc sprintf "%%%02x",ord $1 /eg;
	$encd =~ tr/ /+/;

	return $encd;
}


1;


