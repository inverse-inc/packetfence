package pfappserver::View::CSV;

use strict;
use warnings;

use base 'Catalyst::View::TT';
use Text::CSV;

__PACKAGE__->config(
    TEMPLATE_EXTENSION => '.tt',
    render_die => 1,
    expose_methods => [qw(combine combine_row)]
);


sub process {
    my ($self,$c) = @_;
    my $name = $c->action->name;
    $c->response->header( 'Content-Type' => "text/csv");
    $c->response->header( 'Content-Disposition' => "attachment; filename=${name}.csv");
    return $self->SUPER::process($c);
}

sub combine_row {
    my ($self,$c,$col_names,$row) = @_;
    my $csv = Text::CSV->new( {always_quote => 1 });
    my @columns = map { $row->{$_} } @$col_names;
    my $status = $csv->combine(@columns);    # combine columns into a string
    return $csv->string();             # get the combined string
}

sub combine {
    my ($self,$c,$cols) = @_;
    my $csv = Text::CSV->new();
    my $status = $csv->combine(@$cols);    # combine columns into a string
    return $csv->string();             # get the combined string
}

=head1 NAME

pfappserver::View::CSV - TT View for pfappserver

=head1 DESCRIPTION

TT View for pfappserver.

=head1 SEE ALSO

L<pfappserver>

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
