package pf::cmd;

=head1 NAME

pf::cmd add documentation

=head1 DESCRIPTION

pf::cmd

=cut

use strict;
use warnings;

sub new {
    my ($class,$args) = @_;
    my $self = bless $args,$class;
    return $self;
}

my $delimiter = '|';

use pf::config::ui;

sub print_results {
    my ($self, $function, $key, %params ) = @_;
    my $count  = $ENV{PER_PAGE};
    my $offset = $ENV{PAGE_NUM};
    if ( $offset && $offset > 0 ) {
        $offset = $offset - 1;
        $offset = $offset * $count;
    }

    my $total;
    my @results;
    # calling a function looked up dynamically: first test coderef existence
        # then execute the method (looking up using main::..)
    @results = &{$function}($key, %params);
    $total = scalar(@results);
    if ($count) {
        $offset = scalar(@results) if ( $offset > scalar(@results) );
        $count = scalar(@results) - $offset
            if ( $offset + $count > scalar(@results) );
        @results = splice( @results, $offset, $count );
    }

    my @fields = pf::config::ui->instance->field_order($self->field_order_ui);
    push @fields, keys( %{ $results[0] } ) if ( !scalar(@fields) );

    if ( scalar(@fields) ) {
        print join( $delimiter, @fields ) . "\n";
        foreach my $row (@results) {
            next
                if ( defined( $row->{'mydate'} )
                && $row->{'mydate'} =~ /^00/ );
            my @values = ();
            foreach my $field (@fields) {
                my $value = $row->{$field};
                if ( defined($value) && $value !~ /^0000-00-00 00:00:00$/ ) {

                    # little hack to reverse dates
                    if ( $value =~ /^(\d+)\/(\d+)$/ ) {
                        $value = "$2/$1";
                    } elsif ( $value =~ /^(\d+)\/(\d+)\/(\d+)$/ ) {
                        $value = "$2/$3/$1";
                    }
                    push @values, $value;
                } else {
                    push @values, "";
                }
            }
            print join( $delimiter, @values ) . "\n";
        }
    }
    return ($total);
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>


=head1 COPYRIGHT

Copyright (C) 2005-2015 Inverse inc.

=head1 LICENSE

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301,
USA.

=cut

1;

