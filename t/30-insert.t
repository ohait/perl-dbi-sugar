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

    EXPECT {
        is($NAME, 'prepare', 'prepare');
        like($_[0], qr/INTO.*myTab.*VALUES/s, 'statement');
        return $mock;
    };
    EXPECT {
        is($NAME, 'execute', 'execute');
        is(scalar(@_), 3, '2 args');
        my @x = sort @_;
        is($x[0], 100, 'arg 100');
        is($x[1], 123, 'arg 123');
        is($x[2], 'abc', 'arg abc');
    };

    INSERT myTab => {
        id => 123,
        a => 'abc',
        ct => 100,
    };

    EXPECT {
        is($NAME, 'commit', 'commit');
    };
    return 1;
};

done_testing();
