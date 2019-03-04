package pf::Authentication::Condition;

=head1 NAME

pf::Authentication::Condition

=head1 DESCRIPTION

=cut

use Moose;
use pf::log;

use pf::Authentication::constants;
use Time::Period;

has 'attribute' => (isa => 'Str', is => 'rw', required => 1);
has 'operator' => (isa => 'Str', is => 'rw', required => 1);
has 'value' => (isa => 'Str', is => 'rw', required => 1);

=head1 METHODS

=head2 description

=cut

sub description {
    my ($self) = @_;

    return join(" ", ($self->attribute, $self->operator, $self->value));
}

=head2 matches

=cut

sub matches {
    my ($self, $attr, $v) = @_;

    if (defined $v) {

        my $value = $self->value;
        my $operator = $self->operator;
        my $attribute = $self->attribute;

        my ($time, $time_v);

        if ($attribute eq 'current_time') {
            my ($hour, $min) = $value =~ m/(\d+):(\d+)/;
            my ($vhour, $vmin) = $v =~ m/(\d+):(\d+)/;
            $time = int(sprintf("%d%02d", $hour, $min));
            $time_v = int(sprintf("%d%02d", $vhour, $vmin));
        }
        elsif ($attribute eq 'current_date') {
            my ($year, $mon, $day) = $value =~ m/(\d{4})-(\d{1,2})-(\d{1,2})/;
            my ($vyear, $vmon, $vday) = $v =~ m/(\d{4})-(\d{1,2})-(\d{1,2})/;
            $time = int(sprintf("%d%02d%02d", $year, $mon, $day));
            $time_v = int(sprintf("%d%02d%02d", $vyear, $vmon, $vday));
        }

        my $logger = get_logger();
        $logger->trace(sprintf("Matching condition '%s %s %s' for value '$v'", $attribute, $operator, $value, $v));

        if ($operator eq $Conditions::EQUALS ||
            $operator eq $Conditions::IS) {
            if ($value eq $v) {
                return 1;
            }
        }
        elsif ($operator eq $Conditions::IS_NOT) {
            if ($value ne $v) {
                return 1;
            }
        }
        elsif ($operator eq $Conditions::CONTAINS) {
            if (index($v, $value) >= 0) {
                return 1;
            }
        }
        elsif ($operator eq $Conditions::STARTS) {
            if (index($v, $value) == 0) {
                return 1;
            }
        }
        elsif ($operator eq $Conditions::ENDS) {
            if (($v =~ m/\Q$value\E$/)) {
                return 1;
            }
        }
        elsif ($operator eq $Conditions::MATCHES) {
            if (($v =~ m/$value/)) {
                return 1;
            }
        }
        elsif ($operator eq $Conditions::IS_BEFORE) {
            if ($time_v < $time) {
                return 1;
            }
        }
        elsif ($operator eq $Conditions::IS_AFTER) {
            if ($time_v > $time) {
                return 1;
            }
        }
        elsif ($operator eq $Conditions::IN_TIME_PERIOD) {
            my $r = inPeriod($v, $value);
            if ( $r == 1 ) {
                return 1;
            }
            if ($r == -1) {
                $logger->error("Invalid time period spec $value");
            }
        }
        else {
            my $logger = get_logger();
            $logger->error("Support for operator " . $self->{operator} . " is not implemented.");
        }
    }

    return 0;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2019 Inverse inc.

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

__PACKAGE__->meta->make_immutable unless $ENV{"PF_SKIP_MAKE_IMMUTABLE"};
1;

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:
