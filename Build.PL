use 5.006;
use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'DBI::Sugar',
    license             => 'perl',
    dist_author         => q{Francesco Rivetti <oha@oha.it>},
    dist_version_from   => 'lib/DBI/Sugar.pm',
    build_requires => {
        'Test::More' => 0,
    },
    requires => {
        'perl' => 5.006,
        'DBI' => 0,
    },
    add_to_cleanup      => [ 'DBI-Sugar-*' ],
    create_makefile_pl => 'traditional',
);

$builder->create_build_script();
