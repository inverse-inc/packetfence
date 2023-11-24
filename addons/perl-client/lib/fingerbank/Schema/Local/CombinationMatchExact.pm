package fingerbank::Schema::Local::CombinationMatchExact;

use Moose;
use namespace::autoclean;

extends 'fingerbank::Base::Schema::CombinationMatchExact';

# Special case, we have wildcards when the column is empty
# This view handles it

# $1 = dhcp_fingerprint
# $2 = dhcp_vendor
# $3 = user_agent
# $4 = mac_vendor
# $5 = dhcp6_fingerprint
# $6 = dhcp6_enterprise
__PACKAGE__->view_with_named_params(q{
    SELECT * FROM combination
    WHERE (dhcp_fingerprint_id = $1 OR dhcp_fingerprint_id='')
        AND (dhcp_vendor_id = $2 OR dhcp_vendor_id='')
        AND (user_agent_id = $3 OR user_agent_id='')
        AND ((mac_vendor_id = $4 OR mac_vendor_id IS NULL) OR mac_vendor_id='')
        AND (dhcp6_fingerprint_id = $5 OR dhcp6_fingerprint_id='')
        AND (dhcp6_enterprise_id = $6 OR dhcp6_enterprise_id='')
    ORDER BY
    score DESC LIMIT 1
});

__PACKAGE__->meta->make_immutable;

1;
