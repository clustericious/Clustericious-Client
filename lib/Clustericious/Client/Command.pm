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
use File::Temp;

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

our $Ssh = "ssh -o StrictHostKeyChecking=no -o BatchMode=yes -o PasswordAuthentication=no";
sub _expand_remote_glob {
    # Given a glob, e.g. omidev.gsfc.nasa.gov:/devsips/app/*/doc/Description.txt
    # Return a list of filenames with the host prepended to each one, e.g.
    #       omidev.gsfc.nasa.gov:/devsips/app/foo-1/doc/Description.txt
    #       omidev.gsfc.nasa.gov:/devsips/app/bar-2/doc/Description.txt
    my $pattern = shift;
    return ( $pattern ) unless $pattern =~ /^(\S+):(.*)$/;
    my ($host,$file) = ( $1, $2 );
    return ( $pattern ) unless $file =~ /[*?]/;
    INFO "Remote glob : $host:$file";
    my $errs =  File::Temp->new();
    my @filenames = `$Ssh $host ls $file 2>$errs`;
    LOGDIE "Error ssh $host ls $file returned (code $?)".`tail -2 $errs` if $?;
    return map "$host:$_", @filenames;
}

sub _load_yaml {
    # _load_yaml can take a local filename or a remote ssh host + filename and
    # returns parsed yaml content.
    my $filename = shift;

    unless ($filename =~ /^(\S+):(.*)$/) {
        INFO "Loading $filename";
        my $parsed = LoadFile($filename) or LOGDIE "Invalid YAML : $filename\n";
        return $parsed;
    }

    my ($host,$file) = ($1,$2);
    INFO "Loading remote file $file from $host";
    my $errs =  File::Temp->new();
    my $content = `$Ssh $host cat $file 2>$errs`;
    if ($?) {
        LOGDIE "Error (code $?) running ssh $host cat $file : ".`tail -2 $errs`;
    }
    my $parsed = Load($content) or do {
        ERROR "Invalid YAML: $filename";
        return;
    };
    return $parsed;
}

sub run {
    my $class = shift;
    my $client = shift;

    return $class->_usage($client) if !$ARGV[0] || $ARGV[0] =~ /help/;

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

    my $method = $arg or $class->_usage($client);

    # Map some alternative command line forms.
    my $try_stdin;
    if ( $method eq 'create' ) {
        $method = shift @_ or $class->_usage( $client, "Missing <object>" );
        $try_stdin = 1;
    }

    if ( $method =~ /^(delete|search)$/ ) { # e.g. search -> app_search
        $method = ( shift @_ ) . '_' . $method;
    }

    unless ($client->can($method)) {
        $class->_usage($client, "Unrecognized arguments");
        return;
    }

    my $meta = Clustericious::Client::Meta::Route->new(
        route_name   => $method,
        client_class => ref $client
    );

    my @extra_args = ( '/dev/null' );
    my $have_filenames;

    # Currently only support one filename or a remote glob
    # This can be improved if we add full argument processing too
    # before dispatching.
    if ( !$meta->get('dont_read_files') && @_ > 0 && ( -r $_[-1] || $_[-1] =~ /^\S+:/ ) ) {
        @extra_args = _expand_remote_glob(pop @_);
        $have_filenames = 1;
    } elsif ( $try_stdin && (-r STDIN) && @_==0) {
        my $content = join '', <STDIN>;
        $content = Load($content);
        LOGDIE "Invalid yaml content in $method" unless $content;
        push @_, $content;
    }

    # Finally, run :
    for my $arg (@extra_args) {
        my $obj;
        if ($have_filenames) {
            $obj = $client->$method(@_, _load_yaml($arg));
        } else {
            $obj = $client->$method(@_);
        }
        ERROR $client->errorstring if $client->errorstring;
        next unless $obj;

        if ( blessed($obj) && $obj->isa("Mojo::Transaction") ) {
            if ( my $res = $obj->success ) {
                print $res->code," ",$res->default_message,"\n";
            } else {
                my ( $message, $code ) = $obj->error;
                ERROR $code if $code;
                ERROR $message;
            }
        } elsif (ref $obj eq 'HASH' && keys %$obj == 1 && $obj->{text}) {
            print $obj->{text};
        } elsif ($client->tx->req->method eq 'POST' && $meta->get("quiet_post")) {
            my $msg = $client->res->code." ".$client->res->default_message;
            my $got = $client->res->json;
            if ($got && ref $got eq 'HASH' and keys %$got==1 && $got->{text}) {
                $msg .= " ($got->{text})";
            }
            INFO $msg;
        } else {
           print _prettyDump($obj);
        }
    }
    return;
}

sub _prettyDump {
    my $what = shift;
    rmap_ref { $_ = $_->iso8601() if ref($_) eq 'DateTime' } $what;
    return Dump($what);
}


1;
