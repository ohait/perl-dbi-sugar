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
        is($NAME, 'prepare', 'prepare');
        like($_[0], qr/myTab/, 'statement');
        return $mock;
    };
    EXPECT {
        is($NAME, 'execute', 'execute');
        is(scalar(@_), 2, '2 args');
        is($_[0], 12, '1st arg');
        is($_[1], 34, '2nd arg');
    };

    SQL_DO "DELETE FROM myTab WHERE id IN (?, ?)" => [12,34];

    EXPECT {
        is($NAME, 'commit', 'commit');
    };
    return 1;
};
is($out, 1, 'TX return scalar');

done_testing();
