=head1 NAME

Clustericious::Client::Meta::Route - metadata about a route

=head1 DESCRIPTION

Keep track of metadata about a particular route.  This includes
documentation and attributes.

=head1 SYNOPSIS

    my $meta = Clustericious::Client::Meta::Route->new(
            client_class => 'Yars::Client',
            route_name => 'bucket_map,
        );
    $meta->get('auto_failover');

=cut

package Clustericious::Client::Meta::Route;
use Clustericious::Log;
use Clustericious::Client::Meta;
use DateTime::Format::DateParse;
use Getopt::Long qw/GetOptionsFromArray/;
use Mojo::Base qw/-base/;

has 'client_class';
has 'route_name';

=head2 set

Set a route attribute.

  $meta->set(auto_failover => 1);

=cut

sub set {
    my $self = shift;
    return Clustericious::Client::Meta->add_route_attribute(
        $self->client_class, $self->route_name, @_ );
}

=head2 get

Get a route attribute.

 $meta->get('auto_failover');

=cut

sub get {
    my $self = shift;
    return Clustericious::Client::Meta->get_route_attribute(
        $self->client_class, $self->route_name, @_ );
}

=head2 doc

Get documentation for this route.

=cut

sub doc {
    my $self = shift;
    return Clustericious::Client::Meta->get_route_doc(
        $self->client_class, $self->route_name, @_
    );
}

=head2 set_doc

Set the documentation for a route.

=cut

sub set_doc {
    my $self = shift;
    return Clustericious::Client::Meta->add_route(
        $self->client_class, $self->route_name, @_
    );
}

=head2 client_class

The class of the client associated with this object.

=head2 route_name

The name of the route to which this object refers.

=head2 process_args

Process an array of arguments sent to this route.

This will look at the the route_arg specification that
has been set up for this route, and use it to turn
an array of parameters into hash for use by the method.

If any of the args have a 'preprocess' (list, yamldoc, datetime),
then those transformations are applied.

If any required parameters are missing, an exception is thrown.

If any parameters have an 'alt' entry or are abbreviated, the
full name is used instead.

Returns a hash of arguments, dies on failure.

See route_arg for a complete description of how arguments will
be processed.  Note that modifies_url entries are not processed
here; that occurs just before the request is made.

=cut

sub process_args {
    my $meta = shift;
    my @args = @_;
    my $cli;
    if (ref $args[0] eq 'HASH' && $args[0]{command_line}) {
        $cli = 1;
        shift @args;
    }
    my $route_args = $meta->get('args') or return @args;
    unless ($cli) {
        # method call.
        LOGDIE "Expected name value pairs, not '@args'" unless @args % 2==0;
        my @new;
        while (my ($k,$v) = splice @args, 0, 2) {
            push @new, "--$k", $v;
        }
        @args = @new;
    }

    my %req = map { $_->{required} ? ($_->{name} => 1):() } @$route_args;
    my @getopt = map {
         $_->{name}
         .($_->{alt} ? "|$_->{alt}" : "")
         .($_->{type} || '')
         } @$route_args;

    my $doc = join "\n", "Valid options for '".$meta->route_name."' are :",
      map {
         sprintf('  --%-20s%-15s%s', $_->{name}, $_->{required} ? 'required' : '', $_->{doc} || "" )
       } @$route_args;

    my %method_args;
    GetOptionsFromArray(\@args, \%method_args, @getopt) or LOGDIE "Invalid options. $doc\n";

    for (@$route_args) {
        my $name = $_->{name};
        next unless $_->{required};
        next if exists($method_args{$name});
        LOGDIE "Missing value for required argument '$name'\n$doc\n";
    }

    # Maybe positional params can eat up @args.
    for (@$route_args) {
        next unless @args;
        my $spec = $_->{positional} or next;
        my $name = $_->{name};
        for ($spec) {
            /one/ and do {
                $method_args{$name} = shift @args;
                next;
            };
            /many/ and do {
                push @{ $method_args{$name} }, shift @args while @args;
                next;
            };
            die "unknown positional spec : $spec";
        }
    }

    LOGDIE "Unknown option : @args\n$doc\n" if @args;
    for (@$route_args) {
        my $name = $_->{name};
        next unless $_->{preprocess};
        LOGDIE "internal error: cannot handle $_->{preprocess}" unless $_->{preprocess} =~ /yamldoc|list|datetime/;
        my $filename = $method_args{$name} or next;
        LOGDIE "Argument for $name should be a filename, an arrayref or - for STDIN" if $filename && $filename =~ /\n/;
        next if ref $filename eq 'ARRAY';
        LOGDIE "Cannot read file $filename" unless $filename eq '-' || -e $filename;
        for ($_->{preprocess}) {
            /yamldoc/ and do {
                $method_args{$name} = ($filename eq "-" ? Load(join "",<STDIN>) : LoadFile($filename))
                        or LOGDIE "Error parsing yaml in ($filename)";
                next;
            };
            /list/ and do {
                $method_args{$name} = [ map { chomp; $_ } IO::File->new("< $filename")->getlines ];
                next;
            };
            /^datetime$/ and do {
                $method_args{$name} = DateTime::Format::DateParse->parse_datetime($method_args{$name})->iso8601();
                next;
            };
        }
    }
    return %method_args;
}

=head1 SEE ALSO

Clustericious::Client::Meta

=cut

1;

