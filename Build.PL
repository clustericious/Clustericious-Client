#!/usr/bin/env perl

use strict;
use warnings;

use Module::Build;

my $build = Module::Build->new(
    module_name => 'Clustericious::Client',
    dist_version_from => 'lib/Clustericious/Client.pm',
    requires => {
        'Mojo::Client'  => 0,
        'Clustericious' => 0,
        'JSON::XS'      => 0,
    }
)->create_build_script;
