#!/usr/bin/env perl

use strict;
use warnings;

use Module::Build;

my $build = Module::Build->new(
    module_name => 'Clustericious::Client',
    dist_version_from => 'lib/Clustericious/Client.pm',
    dist_author => 'Curt Tilmes <Curt.Tilmes@nasa.gov>',
    requires => {
        'Mojolicious'   => 0.999926,
        'Clustericious::Config' => '0.01',
        'JSON::XS'      => 0,
    }
)->create_build_script;
