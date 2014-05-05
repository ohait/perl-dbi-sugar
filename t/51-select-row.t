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
eval {
TX {
    EXPECT {
        is($NAME, 'prepare', 'prepare');
        like($_[0], qr/FROM dbi_sugar WHERE/, 'statement');
        return $mock;
    };
    EXPECT {
        is($NAME, 'execute', 'execute');
        is(scalar(@_), 1, '1 arg');
        is($_[0], 123, 'arg[0]');
        return 1;
    };
    EXPECT {
        is($NAME, 'fetchrow_arrayref', 'fetchrow');
        return [1,2];
    };
    EXPECT {
        is($NAME, 'fetchrow_arrayref', 'fetchrow 2');
        return;
    };
    EXPECT {
        is($NAME, 'finish', 'finish');
    };

    $mock->{NAME} = [qw[id a]];
    my %row = SELECT_ROW "* FROM dbi_sugar WHERE id = ?" => [123];
    is(scalar(keys %row), 2, '2 cols');
    is($row{id}, 1, 'id=>1');
    is($row{a}, 2, 'a=>2');

    EXPECT {
        is($NAME, 'prepare', 'prepare');
        like($_[0], qr/FROM dbi_sugar WHERE/, 'statement');
        return $mock;
    };
    EXPECT {
        is($NAME, 'execute', 'execute');
        is(scalar(@_), 1, '1 arg');
        is($_[0], 123, 'arg[0]');
    };
    EXPECT {
        is($NAME, 'fetchrow_arrayref', 'fetchrow 3');
        return [1,2];
    };
    EXPECT {
        is($NAME, 'fetchrow_arrayref', 'fetchrow 4');
        return [1,2];
    };

    # WILL DIE, so...
    EXPECT {
        is($NAME, 'rollback', 'rollback');
    };
    SELECT_ROW "* FROM dbi_sugar WHERE id = ?" => [123]; # WILL DIE

    die "NEVER EXECUTED";
};
};

done_testing();
