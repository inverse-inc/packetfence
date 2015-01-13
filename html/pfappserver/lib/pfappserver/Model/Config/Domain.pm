package pfappserver::Model::Config::Domain;

=head1 NAME

pfappserver::Model::Config::Domain add documentation

=cut

=head1 DESCRIPTION

pfappserver::Model::Config::Domain

=cut

use HTTP::Status qw(:constants is_error is_success);
use Moose;
use namespace::autoclean;
use pf::config::cached;
use pf::config;
use pf::ConfigStore::Domain;
use pf::util;

extends 'pfappserver::Base::Model::Config';


sub _buildConfigStore { pf::ConfigStore::Domain->new }

=head2 Methods

=over

=item search

=cut

sub search {
    my ($self, $field, $value) = @_;
    my @results = $self->configStore->search($field, $value);
    if (@results) {
        return ($STATUS::OK, \@results);
    } else {
        return ($STATUS::NOT_FOUND,["[_1] matching [_2] not found"],$field,$value);
    }
}

sub run {
    my ($self, $cmd) = @_;

    my $result = `$cmd`;
    my $code = $? >> 8;

    return ($code , $result);

}

sub status {
    my ($self, $domain) = @_;

    my $info = $self->configStore->read($domain);

    my ($winbind_status, $winbind_output) = $self->run("sudo /etc/init.d/winbind.$domain status");
    my ($ntlm_auth_status, $ntlm_auth_output) = $self->run("/usr/bin/sudo /usr/sbin/chroot /chroots/$domain /usr/bin/ntlm_auth --username=$info->{bind_dn} --password=$info->{bind_pass}");
  
    return ($winbind_status, $winbind_output, $ntlm_auth_status, $ntlm_auth_output);

}

__PACKAGE__->meta->make_immutable;

=back

=head1 COPYRIGHT

Copyright (C) 2014 Inverse inc.

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
