package Swat::Template::Stack;

# Copyright (C) 2004 Shaun Guth
#
# This program is free software; you can redistribute it and/or modify
# it under the same terms as perl itself.

# Swat::Template::Stack is a really easy and great way to use Template Toolkit
# from within your CGI scripts and build up an output page piece by piece.

use 5.006;
use strict;
use warnings;

use Template;


# our template stack
my @STACK;


# constructor
sub new
{
	my $proto = shift;
	my $class = ref($proto) || $proto;
	my $self  = bless( {}, $class );

	$self->template( @_ );

	return $self;
}


# sets or gets our template instance
sub template
{
	my $self = shift;

	if( @_ )
	{
		$self->{'_template'} = 
			ref($_[0]) eq 'Template' ? $_[0] : Template->new(@_);
	}

	return $self->{'_template'};
}


# sticks a new template onto the stack
# arg0: name of the template
# arg1 .. argN: flattened hash, hashref, or arrayref of key/value pairs
sub push
{
	my $self = shift;
	my $name = shift;
	my %data = ();

	# parse arguments for params
	if( @_ ) {
		%data = ref($_[0]) eq 'HASH' ?  %{$_[0]}  :
			ref($_[0]) eq 'ARRAY'? (@{$_[0]}) :
			(@_);
	}

	# merge with default param set
	%data = ( %{ $self->defaults() }, %data );

	# stick on the stack
	CORE::push( @STACK, [ $name, \%data ] );
}


# pops a template off the stack and processes it
# arg0: a field of the next template on the stack to store the output in
# arg1: set to true to overwrite the previous value, default is merge
sub pop
{
	my $self = shift;
	my $tmpl = $self->template();
	my $top  = $self->peek() || return undef;

	# if the top element on the stack is 'frozen', it means that any
	# attempts to pop an element off will just return undef until thawed
	if( exists $top->[2] && $top->[2] )
	{
		return undef;
	}

	# process the template and stash the output
	my $out;
	$tmpl->process( @$top, \$out );

	# check for errors in processing
	if( $tmpl->error() )
	{
		warn $tmpl->error();
	}

	# remove the element from the stack
	CORE::pop( @STACK );

	# should we store the output into a param of the next stack element?
	if( defined($_[0]) && $_[0] ne "" )
	{
		my $old = $self->param($_[0]) || "";
		$self->param( $_[0], $old . $out );
	}

	# return the processing output
	return $out;
}


# pushes a template onto the stack and then pops it into the specified field
# arg0: name of the template to push
# arg1: name of field to pop into (or array ref of options to pass to pop)
# arg2 .. argN: flattened hash, hashref, or arrayref of key/value pairs for the
#		template being pushed
sub pushp
{
	my $self = shift;
	my $name = shift;
	my $pfld = shift;

	if( ref($pfld) ne 'ARRAY' )
	{
		$pfld = [ $pfld ];
	}

	$self->push( $name, @_ );

	return $self->pop( @$pfld );
}


# returns a reference to the top element on the stack
sub peek
{
	return $STACK[ $#STACK ];
}


# sets or gets parameters for the top stack element
# scalar arg0 only: return value of this key in the parameter hash
# arg0 .. argN: flattened hash, hashref, or arrayref of key/value pairs to set
sub param
{
	my $self = shift;
	my $hash = $self->data();

	if( @_ == 1 && !ref($_[0]) )
	{
		return $hash->{$_[0]};
	}

	if( @_ )
	{
		my %data = ref($_[0]) eq 'HASH' ?  %{$_[0]}  :
			   ref($_[0]) eq 'ARRAY'? (@{$_[0]}) :
			   (@_);
		%$hash = ( %$hash, %data );

		return $hash;
	}

	return keys %$hash;
}


# set or get default parameters that will be set for each template processed
sub defaults
{
	my $self = shift;
	my $hash = $self->{'_defaults'} ||= {};

	if( @_ == 1 && !ref($_[0]) )
	{
		return $hash->{$_[0]};
	}

	if( @_ )
	{
		my %data = ref($_[0]) eq 'HASH' ?  %{$_[0]}  :
			   ref($_[0]) eq 'ARRAY'? (@{$_[0]}) :
			   (@_);
		%$hash = ( %$hash, %data );

		return $hash;
	}

	return $hash;
}


# pops the remaining stack elements off returns the output
sub finish
{
	my $self = shift;
	my $output;

	while( $_ = $self->pop() )
	{
		$output = $_;
	}

	return $output;
}


# clears the stack
sub empty 
{
	@STACK = ();
}


# returns the template name of the top stack element
sub name { return (shift)->peek()->[0] }


# returns the parameter data of the top stack element
sub data { return (shift)->peek()->[1] }


# freezes the stack
sub freeze { (shift)->peek()->[2] = 1 }


# thaws the stack
sub thaw { (shift)->peek()->[2] = 0 }


1;


__END__

=head1 NAME

Swat::Template::Stack - A stack-based processor for Template Toolkit 

=head1 SYNOPSIS

B<    In 'index.ttml'>

    <html>
    <head> <title> [% title %] </title> </head>
    <body>
        [% content %]
	<p> Copyright 2003 - <a href="mailto:[% email %]">Mail me!</a> </p>
    </body>
    </html>

B<    In 'matrix.ttml'>

    &lt; Agent [% agent %] &gt; This is our world now.

B<    In your application>

    use Swat::Template::Stack;

    my $stack = Swat::Template::Stack->new({'INCLUDE_PATH'=>'/var/templates'});

    $stack->defaults( 'email' => 'joe@example.com' );

    $stack->push( 'index.ttml' );
    $stack->param( 'title' => 'The world that has been pulled over your eyes...' );

    if( $hardline eq 'cut' ) {
    	# process matrix.ttml, append the output to 'content' of index.ttml
    	$stack->pushp( 'matrix.ttml', 'content', 'agent' => 'Smith' );
    } else {
    	$stack->param( 'content' => '<p> Get to the hardline now! </p>' );
    }

    my $output = $stack->finish();

    print "Content-type: text/html\n\n";
    print $output;

=head1 AUTHOR

Shaun Guth <shaun@l8nite.net>

=head1 LICENSE

Copyright 2003 Shaun Guth <shaun@l8nite.net>
This library is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

