package pfappserver::View::CSV;

=head1 NAME

pfappserver::View::CSV

=head1 DESCRIPTION

Used to render CSV

=cut

use base qw ( Catalyst::View::CSV );

__PACKAGE__->config ( sep_char => ",", suffix => "csv", binary => 1);

sub process {
    my ($self, $c) = @_;
    unless(defined($c->stash->{columns})){
        if(defined($c->stash->{items}->[0])) {
            $c->stash->{columns} = [keys(%{$c->stash->{items}->[0]})];
        }
    }
    $c->stash->{data} = $c->stash->{items};
    $self->SUPER::process($c);
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

__PACKAGE__->meta->make_immutable(inline_constructor => 0) unless $ENV{"PF_SKIP_MAKE_IMMUTABLE"};

1;
