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
TX {
    # this is what we expect from a SELECT
    EXPECT {
        is($NAME, 'prepare', 'prepare');
        like($_[0], qr/FROM dbi_sugar WHERE/, 'statement');
        return $mock;
    };
    EXPECT {
        is($NAME, 'execute', 'execute');
        is(scalar(@_), 3, '3 args');
        is($_[0], 1, 'arg[0]');
        is($_[1], 2, 'arg[1]');
        is($_[2], 3, 'arg[2]');
        $mock->{NAME} = [qw[id a]];
    };
    EXPECT {
        is($NAME, 'fetchrow_arrayref', 'fetchrow');
        return [1,'a'];
    };
    EXPECT {
        is($NAME, 'fetchrow_arrayref', 'fetchrow');
        return [2,'b'];
    };
    EXPECT {
        is($NAME, 'fetchrow_arrayref', 'fetchrow');
        return;
    };
    EXPECT {
        is($NAME, 'finish', 'finish');
    };

    my %m = SELECT { $_{id} => $_{a} } "id, a FROM dbi_sugar WHERE id IN (?,?,?)" => [1,2,3];

    is(scalar(keys %m), 2, '2 entries');
    is($m{1}, 'a', '1=>a');
    is($m{2}, 'b', '2=>b');


    EXPECT {
        is($NAME, 'prepare', 'prepare');
        return $mock;
    };
    EXPECT {
        is($NAME, 'execute', 'execute');
    };
    EXPECT {
        is($NAME, 'fetchrow_arrayref', 'fetchrow');
        return [1,'a'];
    };
    EXPECT {
        is($NAME, 'fetchrow_arrayref', 'fetchrow');
        return [2,'b'];
    };
    EXPECT {
        is($NAME, 'fetchrow_arrayref', 'fetchrow');
        return;
    };
    EXPECT {
        is($NAME, 'finish', 'finish');
    };

    my $ct = SELECT { } "123" => [1,2,3];

    is($ct, 2, '2 rows');

    EXPECT {
        is($NAME, 'commit', 'commit');
        return $mock;
    };
};

done_testing();
