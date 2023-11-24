package fingerbank::Base::Schema::Combination;

use Moose;
use namespace::autoclean;
use fingerbank::Util qw(is_success);

extends 'fingerbank::Base::Schema';

__PACKAGE__->table('combination');

__PACKAGE__->add_columns(
    "id",
    "dhcp_fingerprint_id",
    "dhcp6_fingerprint_id",
    "user_agent_id",
    "created_at",
    "updated_at",
    "device_id",
    "version",
    "dhcp_vendor_id",
    "dhcp6_enterprise_id",
    "score",
    "mac_vendor_id",
    "submitter_id",
);

__PACKAGE__->set_primary_key('id');

# Custom accessor (value) that returns the Combination device_id when called for listing entries
# See L<fingerbank::Base::CRUD::read>
sub value {
    my ( $self ) = @_;
    my ($status, $value) = fingerbank::Model::Device->read($self->device_id);
    if (is_success ($status)) {
        return $value->{'name'};
    }
    return undef;
}

__PACKAGE__->meta->make_immutable;

1;
