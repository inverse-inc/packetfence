package pf::profile::filter;
=head1 NAME

pf::profile::filter the base class for profile filters

=cut

=head1 DESCRIPTION

pf::profile::filter

The base class for profile filters

=head1 SYNOPSIS

my $filter = pf::profile::filter->new({ profile => 'profile', value => 'value' });
$filter->match({ k1 => 'v1', k2 => 'v2' });

=head2 Example filter

    package pf::profile::filter::time_of_day;
    =head1 NAME

    pf::profile::filter::time_of_day

    =cut

    =head1 DESCRIPTION

    pf::profile::filter::time_of_day

    =cut

    use strict;
    use warnings;
    use Date::Format;
    use Moo;
    extends 'pf::profile::filter';


    =head1 METHODS

    =head2 match

        Matches the time of day against the value
        The value is expected to be in the following format 
        Start-End
        From midnight to 6am
        00:00-06:00
        All time must be in the format HH::MM

    =cut

    sub match {
        my ($self) = @_;
        my ($start,$end) = split(/-/,$self->value);
        my $current = time2str("%H:%M",time);
        return ($start le $current) && ($current le $end);
    }

    1;


    You can also see pf::profile::filter::network as another example

=head2 Configuring in admin gui
    
    The new type is automatically picked up by the admin gui as long is it under the namespace pf::profile::filter.
    If any special formating is need the gui refer to the form field pfappserver::Form::Field::ProfileFilter

=cut

use strict;
use warnings;
use Moo;

=head1 ATTRIBUTES

=head2 profile

The name of the profile of the filter

=cut

has profile => ( is => 'ro', required => 1);

=head2 value

The value to be matched against

=cut

has value => ( is => 'ro', required => 1);

=head1 METHODS

=head2 match

Verifies if the hash matches the filter returns value

=cut

sub match { $_[0]->value }

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

