package DBI::Sugar::MySQL;

use 5.006;
use strict;
use warnings;

use DateTime;
use Date::Parse;

=head1 NAME

DBI::Sugar::MySQL - MySQL specific sugar

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

use parent 'DBI::Sugar';

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

    use DBI::Sugar::MySQL;

    DBI::Sugar::factory {
        # must return a DBI connection
    };

    # open a new transaction
    TX {
        # select some rows
        SELECT "id, created WHERE type = ?" => [$type]
        => sub {
            $_{created} # is a Datetime
        };

        SQL_DO "DELETE FROM myTab ORDER BY id ASC LIMIT ?" => [1];
        
        INSERT myTab => {
            a => "Foo",
            b => "Bar",
        };
    };
    # commit if it returns, rollback if it dies

=head1 DESCRIPTION

see L<DBI::Sugar> for the generic documentation

=head2 SELECT and SELECT_ROW

the data returned from the database is first parsed and datetime values are converted to DateTime objects.

Note: it assumes that dates are in UTC

=cut

our $SELECT_ROW_HOOK = sub {
    my ($row, $sth) = @_;
    my @types = @{$sth->{TYPE}//[]};
    for (my $i =0; $i<@$row; $i++) {
        warn "$i: $types[$i] $row->[$i]";
        if ($types[$i] == 11) {
            $row->[$i] = DateTime->from_epoch(epoch => str2time($row->[$i]));
        }
    }
};

our $SELECT_BINDS_HOOK = sub {
    my ($binds) = @_;
    for my $v (@$binds) {
        $v = "$v" if ref $v;
    }
};

sub TX(&) {
    DBI::Sugar::_TX(@_);
}

sub SELECT($$&) {
    $SELECT_BINDS_HOOK->($_[1]);
    DBI::Sugar::_SELECT(@_, $SELECT_ROW_HOOK);
}

sub SELECT_ROW($$) {
    $SELECT_BINDS_HOOK->($_[1]);
    DBI::Sugar::_SELECT_ROW(@_, $SELECT_ROW_HOOK);
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

=cut


sub INSERT_UPDATE($$$) {
    my ($tab, $insert, $update) = @_;
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
