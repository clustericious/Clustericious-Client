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

use File::Basename qw/basename/;
use YAML::XS qw(Load Dump LoadFile);
use Log::Log4perl qw/:easy/;
use Scalar::Util qw/blessed/;
use Data::Rmap qw/rmap_ref/;

use Clustericious::Client::Meta;

sub _usage {
    my $class = shift;
    my $client = shift;
    my $msg = shift;
    my $routes = Clustericious::Client::Meta->routes(ref $client);
    my $objects = Clustericious::Client::Meta->objects(ref $client);
    print STDERR $msg,"\n" if $msg;
    print STDERR "Usage:\n";
    my $name = basename($0);
    print STDERR <<EOPRINT if $routes && @$routes;
@{[ join "\n", map "       $name [opts] $_->[0] $_->[1]", @$routes ]}
EOPRINT
    print STDERR <<EOPRINT if $objects && @$objects;
       $name [opts] <object>
       $name [opts] <object> <keys>
       $name [opts] search <object> [--key value]
       $name [opts] create <object> [<filename list>]
       $name [opts] update <object> <keys> [<filename>]
       $name [opts] delete <object> <keys>

    where "opts" are as described in Log::Log4perl::CommandLine, or
    may be "--remote <remote>" to specify a remote to use from the
    config file (see Clustericious::Client).

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

    my $arg;
    ARG :
    while ($arg = shift @_) {
        for ($arg) {
            /--remote/ and do {
                my $remote = shift;
                TRACE "Using remote $remote";
                $client->remote($remote);
                next ARG;
            };
            last ARG;
        }
    }

    my $method = $arg;

    $class->_usage($client) unless $method;

    if ($method eq 'create')
    {
        $method = shift @_;
        $class->_usage($client,"Missing <object>") unless $method;

        $class->_usage($client,"Invalid method $method") unless $client->can($method);

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
            my $content = Load(join('', <STDIN>))
                or LOGDIE "Invalid YAML content\n";

            $client->$method($content) or ERROR $client->errorstring;
        }
        return;
    }

    if ($method eq 'update')
    {
        $method = shift @_;
        $class->_usage($client,"Missing <object>") unless $method;

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
        print _prettyDump($ret);
        return;
    }

    if ($method eq 'delete')
    {
        $method = shift @_;
        $class->_usage($client,"Missing <object>") unless $method;

        $method .= '_delete';

        $class->_usage($client,"Invalid object $method") unless $client->can($method);

        $client->$method(@_) or ERROR $client->errorstring;
        return;
    }

    if ($method eq 'search')
    {
        $method = shift @_;

        $class->_usage($client,"Missing <object>") unless $method;

        $method .= '_search';

        INFO "calling $method";
        my $ret = $client->$method(@_) or ERROR $client->errorstring;
        print _prettyDump($ret);

        return;
    }


    if ($client->can($method))
    {
        if ( !Clustericious::Client::Meta->get_route_attribute(ref $client,$method,'dont_read_files')
            && $_[-1] && $_[-1] =~ /\.(ya?ml|txt)$/ && -r $_[-1] ) {
            my $filename = pop @_;
            INFO "Reading file $filename";
            my $content = LoadFile($filename)
                or LOGDIE "Invalid YAML: $filename\n";
            push @_, $content;
        }
        if (my $obj = $client->$method(@_))
        {
            if ( blessed($obj) && $obj->isa("Mojo::Transaction") ) {
                if ( my $res = $obj->success ) {
                    print $res->code," ",$res->default_message,"\n";
                }
                else {
                    my ( $message, $code ) = $obj->error;
                    if ($code) {
                        print "$code $message response.\n";
                    }
                    else {
                        print "Connection error: $message\n";
                    }
                }
            } elsif (ref $obj eq 'HASH' && keys %$obj == 1 && $obj->{text}) {
                print $obj->{text};
            } else {
                print _prettyDump($obj);
            }
        }
        else
        {
            ERROR $client->errorstring if $client->errorstring;
        }
        return;
    }

    $class->_usage($client) if $ARGV[0] =~ /help/;
    $class->_usage($client, "Unrecognized arguments");
}

sub _prettyDump {
    my $what = shift;
    rmap_ref { $_ = $_->iso8601() if ref($_) eq 'DateTime' } $what;
    return Dump($what);
}


1;
