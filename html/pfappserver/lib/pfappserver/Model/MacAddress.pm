package pfappserver::Model::MacAddress;

=head1 NAME

pfappserver::Model::MacAddress - Catalyst Model

=head1 DESCRIPTION

Catalyst Model.

=cut

use strict;
use warnings;

use Moose;
use namespace::autoclean;

#use Readonly;
use Time::localtime;
use Time::Local;

use pf::config;
use pf::error qw(is_error is_success);
use pf::util qw(download_oui load_oui);
use Sort::Naturally;
use List::Util qw(first);

=head1 METHODS

=over

=item field_names

Field Name of MacAddress for display

=cut

sub field_names {
    return [qw(oui vendor_info)];
}

=item countAll

count all mac addresses that match search parameters

=cut

sub countAll {
    my ( $self, %params ) = @_;

    my $logger = Log::Log4perl::get_logger(__PACKAGE__);
    my ( $status_msg, $count );
    eval {
        my $greper = sub {1};
        if ( exists $params{where} ) {
            my $where = $params{where};
            if($where->{type} eq 'any' && $where->{like} ne '' ) {
                my $like = $where->{like};
                my $fields = $self->field_names();
                $greper = sub { my $obj = $_; first { $obj->{$_} =~ /\Q$like\E/i} @$fields };
            }
        }
        $count =
            grep {&$greper }
            map  +{ oui => $_ ,vendor_info => join(' ',@{$Net::MAC::Vendor::Cached->{$_}}) } ,
            keys %$Net::MAC::Vendor::Cached;
    };
    if ($@) {
        $status_msg = "Can't count mac addresses from database.";
        $logger->error($status_msg);
        return ($STATUS::INTERNAL_SERVER_ERROR, $status_msg);
    }

    return ( $STATUS::OK, $count);
}

=item search

find all all mac addresses that match search parameters

=cut

sub search {
    my ( $self, %params ) = @_;
    load_oui();
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);
    my ( $status, $status_msg );
    my $items;
    eval {
        my $sorter = sub {$a->{oui} cmp $b->{oui}};
        my $greper = sub {1};

        if ( exists $params{orderby} )
        {
            my ( $field, $order ) =
                $params{orderby} =~ /ORDER BY\s+(.*)\s+(.*)/;
            if ( $order eq 'desc' ) {
                $sorter = sub {$b->{$field} cmp $a->{$field} };
            }
            else {
                $sorter = sub {$a->{$field} cmp $b->{$field} };
            }
        }
        if ( exists $params{where} ) {
            my $where = $params{where};
            if($where->{type} eq 'any' && $where->{like} ne '' ) {
                my $like = $where->{like};
                my $fields = $self->field_names();
                $greper = sub { my $obj = $_; first { $obj->{$_} =~ /\Q$like\E/i} @$fields };
            }
        }
        my @items =
            sort $sorter
            grep {&$greper }
            map  +{ oui => $_ ,vendor_info => join(' ',@{$Net::MAC::Vendor::Cached->{$_}}) } ,
            keys %$Net::MAC::Vendor::Cached;
        if ( exists $params{limit} ) {
            if(my ( $start, $per_page ) = $params{limit} =~ /(\d+)\s*,\s*(\d+)/) {
                if(@items > $per_page) {
                    my $end = ($start+$per_page - 1);
                    if ($end > $#items) {
                        $end = $#items;
                    }
                    @items = @items[$start ..  $end];
                }
            }
        }
        $items = \@items;
    };
    if ($@) {
        $status_msg = "Error $@";
        $logger->error($status_msg);
        return ( $STATUS::INTERNAL_SERVER_ERROR, ["Error [_1]",$@]);
    }

    return ( $STATUS::OK, $items );
}

=back

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
along with this program; if not, write to the Free Softwar
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301,
USA.

=cut

__PACKAGE__->meta->make_immutable;

1;
