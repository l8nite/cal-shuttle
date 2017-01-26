package Swat::Controller;

# Copyright (C) 2004 Shaun Guth
#
# This program is free software; you can redistribute it and/or modify
# it under the same terms as perl itself.

# This is a very clean base class that takes the ideas of writing runmode-based
# applications from CGI::Application.  Swat::Controller does not actually use
# CGI though, it just needs an object that supports the Swat::Interface::Param
# interface and it will work.

use 5.006;
use strict;
use warnings;


# The following subroutines can be overridden in a child class
sub controller_initialize { }; # called before instance is returned to caller
sub controller_prerun     { }; # called prior to executing a run-mode
sub controller_postrun    { }; # called after executing a run-mode
sub controller_teardown   { }; # called before instance is destroyed
sub controller_output     { }; # called with the return value of a run-mode

# This _must_ be overridden or else the controller will not work
#sub controller_fetch_qobj { }; # should return an object implementing the
				# Swat::Interface::Param methods

# Create a new controller instance
sub new
{
	my $proto = shift;
	my $class = ref($proto) || $proto;
	my $self  = bless( {}, $class );

	# check if controller_fetch_qobj is implemented
	unless( $self->can( 'controller_fetch_qobj' ) )
	{
		die "'controller_fetch_qobj' not implemented, bailing out";
	}

	# set defaults
	$self->controller_mode_param( 'rm' );
	$self->controller_runmode( 'default' );

	# hook for subclass initialization
	$self->controller_initialize();

	return $self;
}


# Destroys our controller instance
sub DESTROY { (shift)->controller_teardown(); }


# Determines the proper runmode and runs its callback
sub controller_run
{
	my $self = shift;

	# fetch value for key specified in mode_param() (from query object)
	my $mp = $self->controller_mode_param();
	my $qo = $self->controller_fetch_qobj();

	# store the runmode
	$self->controller_runmode( $qo->param($mp) );

	# hook for subclass pre-run
	$self->controller_prerun();

	# get the callback for this runmode (if valid), check AUTOLOAD if not
	my $m = $self->controller_modes();
	my $r = $self->controller_runmode();
	my $c   = exists $m->{$r} ? $m->{$r} : undef;
	   $c ||= exists $m->{'AUTOLOAD'} ? $m->{'AUTOLOAD'} : undef;

	# die if we can't find that runmode
	die "No such runmode: '$r'" unless defined($c);

	# execute the callback
	my @out = eval { $self->$c(); };

	# if there were errors in the eval(), print them and die
	die "Error executing runmode '$r': $@" if $@;

	# hook for subclass post-run
	$self->controller_postrun();

	# output hook gets called with return values
	$self->controller_output( @out );
}


# Multi-talented mutator, can accept a hashref, array ref, or flattened hash
sub controller_modes
{
	my $self = shift;
	$self->{'_modes'} ||= {};

	if( scalar(@_) ) {
		my %data = ref($_[0]) eq 'HASH' ? %{$_[0]} :
			   ref($_[0]) eq 'ARRAY'? map{$_=>$_} @{$_[0]} : (@_);
		%{ $self->{'_modes'} } = ( %{ $self->{'_modes'} }, %data );
	}

	return $self->{'_modes'};
}


# Mutator for mode parameter
sub controller_mode_param
{
	my $self = shift;

	if( @_ ) {
		$self->{'_mode_param'} = shift;
	}

	return $self->{'_mode_param'} || 'rm';
}


# Mutator for current runmode
sub controller_runmode
{
	my $self = shift;

	if( @_ ) {
		$self->{'_runmode'} = shift;
	}

	return $self->{'_runmode'} || 'default';
}


1;


