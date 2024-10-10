package fingerbank::Base::Schema::CombinationMatchExact;

use Moose;
use namespace::autoclean;

extends 'fingerbank::Base::Schema';

__PACKAGE__->table_class('DBIx::Class::ResultSource::View');

__PACKAGE__->table('combinationmatchexact');

__PACKAGE__->add_columns(
    "id",
    "score",
    "dhcp_fingerprint_id",
    "dhcp6_fingerprint_id",
    "dhcp_vendor_id",
    "dhcp6_enterprise_id",
    "user_agent_id",
    "mac_vendor_id",
    "device_id",
);

__PACKAGE__->set_primary_key('id');

__PACKAGE__->result_source_instance->is_virtual(1);

# $1 = dhcp_fingerprint
# $2 = dhcp_vendor
# $3 = user_agent
# $4 = mac_vendor
# $5 = dhcp6_fingerprint
# $6 = dhcp6_enterprise
__PACKAGE__->view_with_named_params(q{
    SELECT * FROM combination
    WHERE dhcp_fingerprint_id = $1
        AND dhcp_vendor_id = $2
        AND user_agent_id = $3
        AND mac_vendor_id = $4
        AND dhcp6_fingerprint_id = $5
        AND dhcp6_enterprise_id = $6
    ORDER BY
    score DESC LIMIT 1
});

__PACKAGE__->meta->make_immutable;

1;
