package pf::Authentication::Condition;

=head1 NAME

pf::Authentication::Condition

=head1 DESCRIPTION

=cut

use Moose;
use pf::log;

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

my %OPS = (
    $Conditions::EQUALS => sub {
        return $_[0] eq $_[1];
    },
    $Conditions::IS => sub {
        return $_[0] eq $_[1];
    },
    $Conditions::IS_NOT => sub {
        return $_[0] ne $_[1];
    },
    $Conditions::CONTAINS  => sub {
        return index($_[1], $_[0]) >= 0;
    },
    $Conditions::STARTS  => sub {
        return index($_[1], $_[0]) == 0;
    },
    $Conditions::ENDS => sub {
        return $_[1] =~ m/\Q$_[0]\E$/;
    },
    $Conditions::MATCHES => sub {
        return $_[1] =~ m/\Q$_[0]\E/;
    },
    $Conditions::IS_BEFORE => sub {
        return $_[0] < $_[1];
    },
    $Conditions::IS_AFTER => sub {
        return $_[0] > $_[1];
    }
);

sub matches {
    my ($self, $attr, $v) = @_;
    if (defined $v) {
        my $value = $self->{value};
        if ($self->{'attribute'} eq 'current_time') {
            my ($hour, $min) = $value =~ m/(\d+):(\d+)/;
            $value = int(sprintf("%d%02d", $hour, $min));
        }
        elsif ($self->{'attribute'} eq 'current_date') {
            my ($year, $mon, $day) = $value =~ m/(\d{4})-(\d{,2})-(\d{,2})/;
            $value = int(sprintf("%d%02d%02d", $year, $mon, $day));
        }
        my $op = $self->{'operator'};
        if(exists $OPS{$op}) {
            return $OPS{$op}->($v, $value) ? 1 : 0;
        }
        else {
            my $logger = get_logger();
            $logger->error("Support for operator $op is not implemented.");
        }
    }
    return 0;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2016 Inverse inc.

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
