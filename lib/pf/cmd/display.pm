package pf::cmd::display;
=head1 NAME

pf::cmd::display the base class for displaying items

=cut

=head1 DESCRIPTION

pf::cmd::display

=cut

use strict;
use warnings;
use base qw(pf::cmd);

sub _run {
    my ($self) = @_;
    return $self->print_results;
}

our $delimiter = '|';
our $count  = $ENV{PER_PAGE};
our $offset = $ENV{PAGE_NUM};

sub print_results {
    my ($self) = @_;
    my $function = $self->{function};
    my $key = $self->{key};
    my %params = %{$self->{params}};
    my $total;
    my @results;
    # calling a function looked up dynamically: first test coderef existence
    my $functionName = $function;
    if ( !defined($functionName) ) {
        print "No such sub $function at line ". __LINE__ .".\n";
    } else {
        # then execute the method (looking up using main::..)
        @results = &$function($key, %params);
    }
    $total = scalar(@results);
    if ($count) {
        $offset = scalar(@results) if ( $offset > scalar(@results) );
        $count = scalar(@results) - $offset
            if ( $offset + $count > scalar(@results) );
        @results = splice( @results, $offset, $count );
    }

    my @fields = $self->field_order;
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

sub showHelp {
    my ($self) = @_;
    $self->SUPER::showHelp(ref($self->{parentCmd}) || $self->{parentCmd});
}

sub field_order {
    my ($self) = @_;
    require pf::config::ui;
    import pf::config::ui;
    return pf::config::ui->instance->field_order($self->field_ui);
}

sub field_ui { "@ARGV" }

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

Minor parts of this file may have been contributed. See CREDITS.

=head1 COPYRIGHT

Copyright (C) 2005-2019 Inverse inc.

=head1 LICENSE

This program is free software; you can redistribute it and::or
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

