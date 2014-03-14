package DBI::Sugar;

use 5.006;
use strict;
use warnings;

=head1 NAME

DBI::Sugar - The great new DBI::Sugar!

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

use base 'Exporter';

our @EXPORT = qw(
   TX 
   SELECT
   SELECT_ROW
   SQL_DO
   INSERT
   UPDATE
   DELETE
   INSERT_UPDATE
);

=head1 SYNOPSIS

    use DBI::Sugar;

    DBI::Sugar::factory {
        # must return a DBI connection
    };

    # open a new transaction
    TX {
        # select some rows
        my %rows = SELECT {
            $_{id} => [$_{a}, $_{b}];
        } "id, a, b FROM myTab WHERE status = ? FOR UPDATE" => ['ok'];

        SQL_DO "DELETE FROM myTab ORDER BY id ASC LIMIT ?" => [1];
        
        INSERT myTab => {
            a => "Foo",
            b => "Bar",
        };
    };
    # commit if it returns, rollback if it dies

=head1 DESCRIPTION

=head2 SELECT {...}

How to quickly get data from DB and trasform it:

    my @AoH = SELECT { \%_ } "* FROM myTable" => [];

    my @AoA = SELECT { \@_ } "* FROM myTable" => [];

    my %HoA = SELECT { $_{id} => \@_ } "* FROM myTable" => [];

    my %h = SELECT { @_ } "key, value FROM myTable" => [];


=head2 A Micro Connection Pooler

    my @conns;
    DBI::Sugar::factory {
        my $dbh = shift(@conns) // DBI->connect('dbi:mysql:oha', 'oha', undef, {
                RaiseError => 1,
            });
        return $dbh,
        release => sub {
            push @conns, $dbh;
        };
    };

=head2 A slightly better Micro Connection Pooler

    my @conns;
    DBI::Sugar::factory {
        my $slot = shift @conns;
        $slot //= do {
            my $dbh = DBI->connect('dbi:mysql:oha', 'oha', undef, {
                    RaiseError => 1,
                });
            [$dbh, 0];
        };
        $slot->[1]++;
        return $slot->[0],
        commit => sub {
            $slot->[1]<3 and push @conns, $slot;
        };
    };

=head1 METHODS

=head2 factory

    DBI::Sugar::factory {
        return $dbh;
    };

set the connection factory that will be used by TX

it's possible to add handlers for when the connection will be released:

    DBI::Sugar::factory {
        return $dbh,
            release => sub { ... },
    };

    DBI::Sugar::factory {
        return $dbh,
            commit => sub { ... },
            rollback => sub { ... },
    };

when a commit happen, the C<commit> sub or the C<release> sub is invoked. similarly for rollback

=cut

our $FACTORY;
our $DBH;
our %OPTS;

sub factory(&) {
    ($FACTORY) = @_;
}

sub _make() {
    ($DBH, %OPTS) = $FACTORY->();
    $DBH or die "factory returned a null connection";
    $OPTS{commit} //= $OPTS{release} // sub {};
    $OPTS{rollback} //= $OPTS{release} // sub {};
}

=head2 dbh

    my $dbh = DBI::Sugar::dbh();

return the current DBH (as in, the one in the current transaction, that
would be used by the next statement)

=cut

sub dbh() {
    $DBH;
}

=head1 EXPORT

=head2 TX

a transaction block, with a defined connection to the database.

the code will be executed, and if returns normally, the transaction will be committed.

if the code dies, then the transaction is rollbacked and the error is "rethrown"

=cut

=head2 TX, TX_NEW

    TX { ... };
    TX_NEW { ... };

retrieve a DBH using the factory, and open a transaction (begin_work) on it.

the execute the given code. if the code returns the transaction is committed.

if the code dies, then the transaction is rollbacked and the error is rethrown.

The only difference from C<TX> and C<TX_NEW> is that TX will die if already in a transaction.

Note: normally, for TX_NEW to work properly, a different DBH is required, and so the factory
you provided should handle this.

TODO: consider to use savepoints if the database allows it.

=cut

sub TX(&) {
    $DBH and die "already in a transaction";
    _tx(@_);
}

sub TX_NEW(&) {
    _tx(@_);
}

sub _tx {
    my ($code) = @_;

    local $DBH;
    local %OPTS;
    _make();

    $DBH->begin_work();
    my @out;
    my $wa = wantarray;
    my $ok = eval {
        if ($wa) {
            @out = $code->();
        } elsif(defined $wa) {
            $out[0] = $code->(); 
        } else {
            $code->();
        }
        1;
    };
    my $err = $@;

    if ($ok) {
        $DBH->commit();
        $OPTS{commit}->();
        return @out;
    }
    else {
        $DBH->rollback();
        $OPTS{rollback}->();
        die $err;
    }
}

=head2 SELECT

    SELECT { ... } "field1, field2 FROM tab1, tab2 WHERE cond=? OR cond=?" => [@binds];

performs a select on the database. the query string is passed as is, only prepending C<"SELECT "> at
the beginning.

the rowset will be available in the code block both as @_ and %_ (for the latter, the key will be the
column name)

the result of the code block is returned as in a C<map { ... }>


Note: "SELECT " is prepended to the queries automatically.


=head3 why a map-like?

Databases drivers are designed to return data while fetching more on the backend. On some databases you
can even specify to the optimizer you want the first row as fast as possible, instead of being fast
to fetch all the data.

It's generally better then to just use the data while fetched, instead of fetching the whole data first
and then iterating over it.

Normally, while using DBI, you will end up writing code like:

    my $sth = $dbh->prepare("SELECT * FROM myTab WHERE type = ?");
    $sth->execute($type);
    while(my $row = $sth->fetchrows_hashref()) {
        IMPORTANT
        STUFF
        HERE
    } 
    $sth->finish

Using DBI::Sugar it will become:

    SELECT {
        IMPORTANT
        STUFF
        HERE
    } "* FROM myTab WHERE type = ?"
    =>[$type];



=cut

sub SELECT(&$$) {
    my ($code, $query, $binds) = @_;

    my @caller = caller(); my $stm = "-- DBI::Sugar::SELECT() at $caller[1]:$caller[2]\nSELECT $query";

    $DBH or die "not in a transaction";

    my $sth = $DBH->prepare($stm);
    $sth->execute(@$binds);
    my @out;
    my @NAMES = @{$sth->{NAME}};

    while(my $row = $sth->fetchrow_arrayref) {
        my @v = @$row;
        my $i = 0;
        local %_ = map { $_ => $v[$i++] } @NAMES;
        local $_ = $row;
        if (wantarray) {
            push @out, $code->(@v);
        } else {
            $code->(@v);
            $out[0] = ($out[0]//0) +1;
        }
    }
    $sth->finish;
    if (wantarray) {
        return @out;
    } else {
        return $out[0];
    }
}

=head2 SELECT_ROW

    my %row = SELECT_ROW "* FROM myTable WHERE id = ?" => [$id];

fetch a single row from the database, and returns it as an hash

if no rows are found, the hash will be empty

IMPORTANT: it will die if more than one rows are found.

=cut

sub SELECT_ROW($$) {
    my ($query, $binds) = @_;

    my @caller = caller(); my $stm = "-- DBI::Sugar::SELECT_ROW() at $caller[1]:$caller[2]\nSELECT $query";

    $DBH or die "not in a transaction";

    my $sth = $DBH->prepare($stm);
    $sth->execute(@$binds);

    my $row = $sth->fetchrow_hashref();

    if ($sth->fetchrow_hashref) {
        die "expected 1 row, got more: $stm";
    }
    $sth->finish;

    return %$row;
}

=head2 SQL_DO

    SQL_DO "UPDATE myTable SET x=x+?" => [1];

execute a statement and return

=cut

sub SQL_DO($$) {
    my ($query, $binds) = @_;

    my @caller = caller(); my $stm = "-- DBI::Sugar::SQL_DO() at $caller[1]:$caller[2]\n$query";

    $DBH or die "not in a transaction";

    my $sth = $DBH->prepare($stm);
    return $sth->execute(@$binds);
}


=head2 INSERT

    INSERT myTable => {
        id => $id,
        col1 => $col1,
        col2 => $col2, 
    };

Insert into the given table, the given data;

=cut

sub INSERT($$) {
    my ($tab, $data) = @_;

    my @caller = caller(); my $stm = "-- DBI::Sugar::INSERT() at $caller[1]:$caller[2]\n";

    $DBH or die "not in a transaction";

    my @cols;
    my @binds;
    for my $key (keys %$data) {
        push @cols, $key; 
        push @binds, $data->{$key};
    }
    $stm .= "INSERT INTO $tab (".
        join(', ', @cols).") VALUES (".
        join(', ', map { '?' } @cols).")";
    
    my $sth = $DBH->prepare($stm);
    return $sth->execute(@binds);
}

=head2 UPDATE (NIY)

    UPDATE myTable => {
        id => $id
    } => {
        name => $name, 
        x => ['x+?', $y],
    };

=cut

sub UPDATE($$$) {
    my ($tab, $where, $set) = @_;
    die "NIY";
}

=head2 INSERT_UPDATE (NIY)

    INSERT_UPDATE myTable => {
        id => $id,
        name => $name,
        ct => $inc,
        last_update => ['NOW()'],
    } => {
        ct => ['ct+?', $inc],
        last_update => ['NOW()'],
    };

TODO: detect different backends and use specific code?
(mysql: insert ... on duplicate key update)
see also: http://en.wikipedia.org/wiki/Merge_(SQL)

=cut

sub INSERT_UPDATE($$$) {
    my ($tab, $insert, $update) = @_;
    die "NIY";
}

=head2 DELETE (NIY)

    DELETE myTable => {
        status => 'to_delete',
    };

=cut

sub DELETE($$) {
    my ($tab, $where) = @_;
    die "NIY";
}

=head1 AUTHOR

Francesco Rivetti, C<< <oha at oha.it> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-dbi-sugar at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=DBI-Sugar>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc DBI::Sugar

You can also look for information at:

=over 4

=item * GitHub

L<http://github.com/ohait/perl-dbi-sugar>

=back


=head1 ACKNOWLEDGEMENTS

Tadeusz 'tadzik' Sosnierz - to convince me to release this module

=head1 LICENSE AND COPYRIGHT

Copyright 2014 Francesco Rivetti.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1; # End of DBI::Sugar
