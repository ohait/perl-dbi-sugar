# DBI-Sugar

```perl
use DBI::Sugar;

DBI::Sugar::factory {
    return DBI->connect(...);
};

# open a new transaction
TX {
    # select some rows
    my %rows = SELECT "id, name, surname
        FROM people WHERE age >= ? AND age < ?"
    => [18,25]
    => sub {
        $_{id} => join ' ', $_{name}, $_{surname};
    };

    SQL_DO "DELETE FROM myTab ORDER BY id ASC LIMIT ?" => [1];

    my $next;
    TX_NEW {
        (undef, $next) = SELECT_ROW "next FROM ids WHERE type = ?
            FOR UPDATE" => [$type];
        SQL_DO "UPDATE ids SET next = next + 1 WHERE type = ?" => [$type];
    };

    INSERT myTab => {
        id => $next,
        a => "Foo",
        b => "Bar",
    };

    UPDATE myTab => {
        id => $next,
    } => {
        ct => ['ct + ?', $inc],
    }

    # or even more sugar coating!

    my $id = NEXT_ID myTab => 10;
    # reserve 10 ids from table "ids" where name = 'myTab'
    # returns the first, keep the other 9 in a pool

    UPSERT myTab => {
        # WHERE
        key => $id,
    } => {
        # UPDATE
        ct => ['ct + ?', $inc],
        last_mod => ['NOW()'],
    } => {
        # INSERT
        ct => $inc, # override ct
        # last_mod is ok as in the update
        created => ['NOW()'], # but created need to be set
    }
};
# commit if it returns, rollback if it dies
```

## INSTALLATION

To install this module, run the following commands:

	perl Build.PL
	./Build
	./Build test
	./Build install

## SUPPORT AND DOCUMENTATION

After installing, you can find documentation for this module with the
perldoc command.

    perldoc DBI::Sugar

You can also look for information at:

    GitHub
        http://github.com/ohait/perl-dbi-sugar


## LICENSE AND COPYRIGHT

Copyright (C) 2014 Francesco Rivetti

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

