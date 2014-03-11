#!perl -T

package Mock;
use Data::Dumper;
use Test::More;
use DBI::Sugar;

our $AUTOLOAD;
our $NAME;
our @EXPECT;
sub AUTOLOAD {
    my ($self, @args) = @_;
    my (@names) = split /::/, $AUTOLOAD;
    $NAME = pop @names;
    if(my $test = shift @EXPECT) {
        return $test->(@args);
    } else {
        fail("not expected: $NAME()");
    }
}

sub DESTROY {}

sub EXPECT(&) {
    push @EXPECT, $_[0];
}

my $mock = bless {
}, 'Mock';

DBI::Sugar::factory {
    $mock;
};

EXPECT {
    is($NAME, 'begin_work', 'begin_work');
};
my $out = TX {
    EXPECT {
        is($NAME, 'commit', 'commit');
    };
    return 1;
};
is($out, 1, 'TX return scalar');


EXPECT {
    is($NAME, 'begin_work', 'begin_work');
};
my @out = TX {
    EXPECT {
        is($NAME, 'commit', 'commit');
    };
    return 1,2,3;
};
is(scalar(@out), 3, 'TX return list');

eval {
    EXPECT {
        is($NAME, 'begin_work', 'begin_work');
    };
    TX {
        EXPECT {
            is($NAME, 'rollback', 'rollback');
        };
        die "no";
    };
    1;
} and fail('must have died');


DBI::Sugar::factory {
    undef;
};

eval {
    TX { };
    fail('should have died');
    1;
} and fail("should have died");
like("$@", qr/factory/, 'died');


done_testing();
