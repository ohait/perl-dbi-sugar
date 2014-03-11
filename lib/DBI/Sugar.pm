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

=head1 METHODS

=head2 factory

    DBI::Sugar::factory {
        return $dbh;
    };

set the connection factory that will be used by TX

=cut

our $FACTORY;
our $DBH;

sub factory(&) {
    ($FACTORY) = @_;
}

=head2 dbh

    my $dbh = DBI::Sugar::dbh();

invoke the factory and return a DBH

=cut

sub dbh() {
    $FACTORY->();
}

=head1 EXPORT

=head2 TX

a transaction block, with a defined connection to the database.

the code will be executed, and if returns normally, the transaction will be committed.

if the code dies, then the transaction is rollbacked and the error is "rethrown"

=cut

=head2 TX

    TX { ... };

retrieve a DBH using the factory, and open a transaction (begin_work) on it.

the execute the given code. if the code returns the transaction is committed.

if the code dies, then the transaction is rollbacked and the error is rethrown.

TODO: add support for try/catch modules

=cut

sub TX(&) {
    my ($code) = @_;
    local $DBH = $FACTORY->();
    $DBH or die "factory returned a null connection";
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
        return @out;
    }
    else {
        $DBH->rollback();
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

=cut

sub SELECT(&$$) {
    my ($code, $query, $binds) = @_;

    my @caller = caller(); my $stm = "-- DBI::Sugar::SELECT() at $caller[1]:$caller[2]\nSELECT $query";

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

it will die if more than one rows are found.

=cut

sub SELECT_ROW($$) {
    my ($query, $binds) = @_;

    my @caller = caller(); my $stm = "-- DBI::Sugar::SELECT_ROW() at $caller[1]:$caller[2]\nSELECT $query";

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

sub 

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
