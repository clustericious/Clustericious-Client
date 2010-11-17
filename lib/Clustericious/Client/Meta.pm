=head1 NAME

Clustericious::Client::Meta - simple meta object for constructing clients

=head1 METHODS

=over

=cut

package Clustericious::Client::Meta;
use strict;
use warnings;

our %Routes; # hash from class name to array ref of routes.
our %Objects; # hash from class name to array ref of objects.
our @CommonRoutes = ( [ "version" ], [ "status" ] );

=item add_route

Add a route.

Parameters :
    - the name of the client class
    - the name of the route
    - documentation about the route's arguments

=cut

sub add_route { # Keep track of routes that have are added.
    my $class      = shift;
    my $for        = shift;         # e.g. Restmd::Client
    my $route_name = shift;         # same as $subname
    my $route_doc  = shift || '';
    push @{ $Routes{$for} }, [ $route_name => $route_doc ];
}

=item add_object

Add an object>

Parameters :
    - the name of the client class
    - the name of the object
    - documentation about the object.

=cut

sub add_object {
    my $class    = shift;
    my $for      = shift;
    my $obj_name = shift;
    my $obj_doc  = shift || '';
    push @{ $Objects{$for} }, [ $obj_name => $obj_doc ];
}

=item routes, objects

Return an array ref of routes/objects.

Each element is a two element array; the
first element is the name, the second is
documentation.

=cut

sub routes {
    my $class = shift;
    my $for = shift;
    return [ @CommonRoutes, @{$Routes{$for}}];
}

sub objects {
    my $class = shift;
    my $for = shift;
    return $Objects{$for};

}

1;


