#!/usr/bin/env perl

use strict;
use warnings;

use Module::Build;

my $build = Module::Build->new(
    module_name => 'Clustericious::Client',
    dist_version_from => 'lib/Clustericious/Client.pm',
    dist_author => 'Curt Tilmes <Curt.Tilmes@nasa.gov>',
    requires => {
        'Mojolicious'   => '1.01',
        'Clustericious::Config' => '0.01',
        'Log::Log4perl::CommandLine' => 0,
        'MojoX::Log::Log4perl' => 0,
        'JSON::XS'      => 0,
        'Proc::Daemon' => 0,
        'File::Temp' => 0,
    }
)->create_build_script;
