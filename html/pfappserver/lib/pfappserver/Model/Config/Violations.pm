package pfappserver::Model::Config::Violations;

=head1 NAME

pfappserver::Model::Config::Violations - Catalyst Model

=head1 DESCRIPTION

Catalyst Model.

=cut

use strict;
use warnings;

use Config::IniFiles;
use Moose;
use namespace::autoclean;

use pf::config;
use pf::error qw(is_error is_success);

extends 'pfappserver::Model::Config::IniStyleBackend';

sub _myConfigFile { return $conf_dir . "/violations.conf" };

=head1 METHODS

=over

=head2 read_value

=cut
sub read_value {
    my ( $self, $section, $param ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    my $status_msg;

    my $violations_conf = $self->_load_conf();

    # Warning: autovivification causes interfaces to be created if the section
    # is not looked on her own first when the file is written later.
    if (!defined($violations_conf->{$section}) || !defined($violations_conf->{$section}->{$param})) {
        $status_msg = "$section.$param does not exists";
        $logger->warn("$status_msg");
        return ($STATUS::NOT_FOUND, $status_msg);
    }

    $status_msg = $violations_conf->{$section}->{$param} || '';

    return ($STATUS::OK, $status_msg);    
}

=head2 read_violation

=cut
sub read_violation {
    my ( $self, $violation ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    my $violations_conf = $self->_load_conf();
    my @columns = pf::config::ui->instance->field_order('violationconfig get'); 
    my @resultset;

    foreach my $section ( keys %$violations_conf ) {
        # TODO: Ignore disabled violation?
        if ( ($violation eq 'all') || ($violation eq $section) ) {
            my %values = ( id => $section );
            foreach my $column (@columns) {
                $values{$column} = $violations_conf->{$section}->{$column} || '';
            }
            push @resultset, \%values;
        }
    }

    if ( $#resultset > 0 ) {
        return ($STATUS::OK, \@resultset);
    }
    else {
        return ($STATUS::NOT_FOUND, "Unknown violation $violation");
    }
}

=item exists

=cut

sub exists {
    my ( $self, $violation ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    my $violations_conf = $self->_load_conf();
    my $tied_conf = tied(%$violations_conf);

    return $TRUE if ( $tied_conf->SectionExists($violation) );
    return $FALSE;
}

=back

=head1 AUTHORS

Francis Lachapelle <flachapelle@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2012 Inverse inc.

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
