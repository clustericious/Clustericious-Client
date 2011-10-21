=head1 NAME

Clustericious::Client::Meta - simple meta object for constructing clients

=head1 METHODS

=over

=cut

package Clustericious::Client::Meta;
use strict;
use warnings;

our %Routes; # hash from class name to array ref of routes.
our %RouteAttributes; # hash from class name to hash ref of attributes.
our %Objects; # hash from class name to array ref of objects.
our @CommonRoutes = ( [ "version" => '' ], [ "status" => '' ], [ "api" => '' ], [ "logtail" => '' ] );

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

=item add_route_attribute

Add an attribute for a route.

Parameters :

    - the name of the attribute
    - the value of the attribute.

Recognized attributes :

    - dont_read_files : if set, no attempt will be made to treat
        arguments as yaml files

=cut

sub add_route_attribute {
    my $class      = shift;
    my $for        = shift;         # e.g. Restmd::Client
    my $route_name = shift;
    my $attr_name  = shift;
    my $attr_value = shift;
    $RouteAttributes{$for}->{$route_name}{$attr_name} = $attr_value;
}

=item get_route_attrribute

Like the above but retrieve an attribute.

=cut

sub get_route_attrribute {
    my $class      = shift;
    my $for        = shift;         # e.g. Restmd::Client
    my $route_name = shift;
    my $attr_name  = shift;
    return $RouteAttributes{$for}->{$route_name}{$attr_name};
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


