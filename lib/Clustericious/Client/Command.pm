package Clustericious::Client::Command;

=head1 NAME

Clustericious::Client::Command - Command Line type processing for Clients

=head1 SYNOPSIS

 use Foo::Client;
 use Clustericious::Client::Command;

 Clustericious::Client::Command->run(Foo::Client->new, @ARGV);

=head1 DESCRIPTION

This will try to take command line arguments and call the right client
methods.

Still needs lots of work..

=cut

use strict;
use warnings;

use YAML::XS qw(Load Dump LoadFile);
use Log::Log4perl qw/:easy/;
use Data::Dumper;

our @Routes;
our @Objects;

sub add_route { # Keep track of routes that have are added.
    my $class      = shift;
    my $class_for  = shift;         # e.g. Restmd::Client
    my $route_name = shift;         # same as $subname
    my $route_doc  = shift || '';
    push @Routes, [ $route_name => $route_doc ];
}

sub add_object {
    my $class    = shift;
    my $for      = shift;
    my $obj_name = shift;
    my $obj_doc  = shift || '';
    push @Objects, [ $obj_name => $obj_doc ];
}

sub _usage {
    my $msg = shift;
    my $routes = \@Routes;
    my $objects = \@Objects;
    print STDERR $msg,"\n" if $msg;
    print STDERR <<EOPRINT;
Usage:
@{[ join "\n", map "       $0 [log options] $_->[0] $_->[1]", @$routes ]}
       $0 [log options] <object>
       $0 [log options] <object> <keys>
       $0 [log options] create <object> [<filename list>]
       $0 [log options] update <object> <keys> [<filename>]
       $0 [log options] delete <object> <keys>

    where "log options" are as described in Log::Log4perl::CommandLine.

    and "<object>" may be one of the following :
@{[ join "\n", map "      $_->[0] $_->[1]", @$objects ]}
EOPRINT

    exit 0;
}

=head1 METHODS

=head2 C<run>

 Clustericious::Client::Command->run(Some::Clustericious::Client->new, @ARGV);

=cut

sub run
{
    my $class = shift;
    my $client = shift;

    my $method = shift @_;

    _usage() unless $method;

    if ($method eq 'create')
    {
        $method = shift @_;
        _usage("Missing <object>") unless $method;

        _usage("Invalid method $method") unless $client->can($method);

        if (@_)
        {
            foreach my $filename (@_)
            {
                my $content = LoadFile($filename)
                    or LOGDIE "Invalid YAML : $filename\n";
                print "Loading $filename\n";
                $client->$method($content) or ERROR $client->errorstring;
            }
        }
        else
        {
            my $content = Load(join('', <>))
                or LOGDIE "Invalid YAML content\n";

            $client->$method($content) or ERROR $client->errorstring;
        }
        return;
    }

    if ($method eq 'update')
    {
        $method = shift @_;
        _usage("Missing <object>") unless $method;

        my $content;
        if (-r $_[-1])  # Does it look like a filename?
        {
            my $filename = pop @_;
            $content = LoadFile($filename)
                or LOGDIE "Invalid YAML: $filename\n";
            print "Loading $filename\n";
        }
        else
        {
            $content = Load(join('', <STDIN>))
                or LOGDIE "Invalid YAML: stdin\n";
        }
        my $ret = $client->$method(@_, $content)
            or ERROR $client->errorstring;
        print Dump($ret);
        return;
    }

    if ($method eq 'delete')
    {
        $method = shift @_;
        _usage("Missing <object>") unless $method;

        $method .= '_delete';

        _usage("Invalid object $method") unless $client->can($method);

        $client->$method(@_) or ERROR $client->errorstring;
        return;
    }

    if ($client->can($method))
    {
        if (my $obj = $client->$method(@_))
        {
            print Dump($obj);
        }
        else
        {
            ERROR $client->errorstring;
        }
        return;
    }

    _usage if $ARGV[0] =~ /help/;
    _usage( "Unrecognized arguments");
}

1;
