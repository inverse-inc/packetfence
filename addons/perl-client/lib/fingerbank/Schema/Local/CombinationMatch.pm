package fingerbank::Schema::Local::CombinationMatch;

use Moose;
use namespace::autoclean;

extends 'fingerbank::Base::Schema::CombinationMatch';

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
    WHERE dhcp_fingerprint_id = $1 OR dhcp_vendor_id = $2 OR user_agent_id = $3 OR (mac_vendor_id = $4 OR mac_vendor_id IS NULL) OR dhcp6_fingerprint_id = $5 OR dhcp6_enterprise_id = $6
    ORDER BY
    case when (dhcp_fingerprint_id = $1 AND dhcp_fingerprint_id != '0') OR ( $1 = 0 AND dhcp_fingerprint_id = 0 ) OR (dhcp_fingerprint_id='')then 2 else 0 END +
    case when (dhcp_vendor_id = $2 AND dhcp_vendor_id != '0') OR ( $2 = '0' AND dhcp_vendor_id = '0') OR (dhcp_vendor_id='')then 2 else 0 END +
    case when (user_agent_id = $3 AND user_agent_id != '0') OR ($3 = '0' AND user_agent_id = '0') OR (user_agent_id='')then 2 else 0 END +
    case when (dhcp6_fingerprint_id = $5 AND dhcp6_fingerprint_id != '0') OR ($5 = '0' AND dhcp6_fingerprint_id = '0') OR (dhcp6_fingerprint_id='')then 2 else 0 END +
    case when (dhcp6_enterprise_id = $6 AND dhcp6_enterprise_id != '0') OR ($6 = '0' AND dhcp6_enterprise_id = '0') OR (dhcp6_enterprise_id='')then 2 else 0 END +
    case when (mac_vendor_id = $4 OR (mac_vendor_id IS NULL AND $4 IS NULL)) OR (mac_vendor_id='') then 1 else 0 END
    DESC,
    score DESC LIMIT 1
});

__PACKAGE__->meta->make_immutable;

1;
