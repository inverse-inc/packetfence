package pf::Authentication::Condition;

=head1 NAME

pf::Authentication::Condition

=head1 DESCRIPTION

=cut

use Moose;

use pf::Authentication::constants;

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

        my ($time, $time_v);

        if ($self->{'attribute'} eq 'current_time') {
            my ($hour, $min) = $self->{'value'} =~ m/(\d+):(\d+)/;
            my ($vhour, $vmin) = $v =~ m/(\d+):(\d+)/;
            $time = int(sprintf("%d%02d", $hour, $min));
            $time_v = int(sprintf("%d%02d", $vhour, $vmin));
        }
        elsif ($self->{'attribute'} eq 'current_date') {
            my ($year, $mon, $day) = $self->{'value'} =~ m/(\d{4})-(\d{,2})-(\d{,2})/;
            my ($vyear, $vmon, $vday) = $self->{'value'} =~ m/(\d{4})-(\d{,2})-(\d{,2})/;
            $time = int(sprintf("%d%02d%02d", $year, $mon, $day));
            $time_v = int(sprintf("%d%02d%02d", $vyear, $vmon, $vday));
        }

        my $logger = Log::Log4perl->get_logger( __PACKAGE__ );
        $logger->trace(sprintf("Matching condition '%s %s %s' for value '$v'", $self->{'attribute'}, $self->{'operator'}, $self->{'value'}, $v));

        if ($self->{'operator'} eq $Conditions::EQUALS ||
            $self->{'operator'} eq $Conditions::IS) {
            if ($self->{'value'} eq $v) {
                return 1;
            }
        }
        elsif ($self->{'operator'} eq $Conditions::IS_NOT) {
            if ($self->{'value'} ne $v) {
                return 1;
            }
        }
        elsif ($self->{'operator'} eq $Conditions::CONTAINS) {
            if (index($v, $self->{'value'}) >= 0) {
                return 1;
            }
        }
        elsif ($self->{'operator'} eq $Conditions::STARTS) {
            if (index($v, $self->{'value'}) == 0) {
                return 1;
            }
        }
        elsif ($self->{'operator'} eq $Conditions::ENDS) {
            if (($v =~ m/\Q${$self}{value}\E$/)) {
                return 1;
            }
        }
        elsif ($self->{'operator'} eq $Conditions::MATCHES) {
            if (($v =~ m/${$self}{value}/)) {
                return 1;
            }
        }
        elsif ($self->{'operator'} eq $Conditions::IS_BEFORE) {
            if ($time_v < $time) {
                return 1;
            }
        }
        elsif ($self->{'operator'} eq $Conditions::IS_AFTER) {
            if ($time_v > $time) {
                return 1;
            }
        }
        else {
            my $logger = Log::Log4perl->get_logger( __PACKAGE__ );
            $logger->error("Support for operator " . $self->{operator} . " is not implemented.");
        }
    }

    return 0;
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

__PACKAGE__->meta->make_immutable;
1;

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:
