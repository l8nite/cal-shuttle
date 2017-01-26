package Swat::Interface::Param;

# Copyright (C) 2003 Shaun Guth
#
# This program is free software; you can redistribute it and/or modify
# it under the terms same terms as perl itself.

# I'm pretty sure I borrowed this routine (if not the code, then the idea) from
# another module on CPAN, but I can't for the life of me remember which one.
# If anybody ever reads this and recognizes it let me know so I can give the
# author credit.

use 5.006;
use strict;
use warnings;


sub _param
{
	my ($self,$field) = (shift,shift);

	# Initialize empty params hash if this is our first time
	my $data = $self->{$field} ||= {};

	# accept flattened hash (list) of key/value pairs
	if( @_ > 1 )
	{
		die "Element list must be even" unless @_ % 2 == 0;
		%$data = (%$data, @_);
	}
	elsif( @_ == 1 )
	{
		if( ref $_[0] eq 'HASH' ) 
		# Maybe they want us to set a HASHREF
		{
			%$data = (%$data,%{$_[0]});
		}
		else
		# They want us to give them the value for a key
		{
			return $data->{$_[0]};
		}
	}
	else
	# Called with no args, return list of param keys
	{
		return keys %$data;
	}
}


sub param
{
	my $self = shift;
	$self->_param( '__params', @_ );
}


sub clear
{
	my ($self,$field) = @_;
	delete $self->{$field};
}


1;


