package pf::triggerParser;
=head1 NAME

pf::triggerParser

=cut

=head1 DESCRIPTION

pf::triggerParser

=cut

use Moo;


=head2 parseTid

Parse the trigger id

=cut

sub parseTid {
    my ($self, $type, $tid) = @_;
    die("Invalid trigger id: ${type}::${tid}") unless $self->validateTid($tid);
    return [$self->parseTidStartEnd($tid),$type];
}

sub validateTid {
    my ($self,$tid) = @_;
    return $tid =~ /^[L\d\.-]+\s*$/;
}

sub parseTidStartEnd {
    my ($self,$tid) = @_;
    if ($tid =~ /(\d+)-(\d+)/) {
        if ($2 > $1) {
            return ($1, $2);
        }
        else {
            die("Invalid trigger range ($1 - $2)");
        }
    }
    return ($tid,$tid);

}

sub search {
    return [];
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
