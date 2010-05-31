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
use Data::Dumper;

=head1 METHODS

=head2 C<run>

 Clustericious::Client::Command->run(Some::Clustericious::Client->new, @ARGV);

=cut

sub run
{
    my $class = shift;
    my $client = shift;

    my $method = shift @_;

    return warn "Usage: $0 <object> <keys>\n" .
                "       $0 create <object> [<filename list>]\n" .
                "       $0 update <object> <keys> [<filename>]\n" .
                "       $0 delete <object> <keys>\n" unless $method;

    if ($method eq 'create')
    {
        $method = shift @_;
        die "Missing <object>\n" unless $method;

        die "Invalid method $method\n" unless $client->can($method);

        if (@_)
        {
            foreach my $filename (@_)
            {
                my $content = LoadFile($filename)
                    or die "Invalid YAML : $filename\n";
                print "Loading $filename\n";
                $client->$method($content) or warn $client->errorstring;
            }
        }
        else
        {
            my $content = Load(join('', <>))
                or die "Invalid YAML content\n";

            $client->$method($content) or warn $client->errorstring;
        }
        return;
    }

    if ($method eq 'update')
    {
        $method = shift @_;
        die "Missing <object>\n" unless $method;

        my $content;
        if (-r $_[-1])  # Does it look like a filename?
        {
            my $filename = pop @_;
            $content = LoadFile($filename)
                or die "Invalid YAML: $filename\n";
            print "Loading $filename\n";
        }
        else
        {
            $content = Load(join('', <STDIN>))
                or die "Invalid YAML: stdin\n";
        }
        my $ret = $client->$method(@_, $content)
            or warn $client->errorstring;
        print Dump($ret);
        return;
    }

    if ($method eq 'delete')
    {
        $method = shift @_;
        die "Missing <object>\n" unless $method;

        $method .= '_delete';

        die "Invalid object $method\n" unless $client->can($method);

        $client->$method(@_) or warn $client->errorstring;
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
            warn $client->errorstring;
        }
        return;
    }

    die "Invalid args\n";
}

1;
