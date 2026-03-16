use strict;
use warnings;

our (%RAD_REQUEST, %RAD_REPLY, %RAD_CHECK, %RAD_STATE, %RAD_CONFIG, %RAD_REQUEST_PROXY_REPLY);

use constant {
	RLM_MODULE_REJECT   => 0, # immediately reject the request
	RLM_MODULE_OK       => 2, # the module is OK, continue
	RLM_MODULE_HANDLED  => 3, # the module handled the request, so stop
	RLM_MODULE_INVALID  => 4, # the module considers the request invalid
	RLM_MODULE_USERLOCK => 5, # reject the request (user is locked out)
	RLM_MODULE_NOTFOUND => 6, # user not found
	RLM_MODULE_NOOP     => 7, # module succeeded without doing anything
	RLM_MODULE_UPDATED  => 8, # OK (pairs modified)
	RLM_MODULE_NUMCODES => 9  # How many return codes there are
};

# Same as src/include/log.h
use constant {
	L_AUTH         => 2,  # Authentication message
	L_INFO         => 3,  # Informational message
	L_ERR          => 4,  # Error message
	L_WARN         => 5,  # Warning
	L_PROXY        => 6,  # Proxy messages
	L_ACCT         => 7,  # Accounting messages
	L_DBG          => 16, # Only displayed when debugging is enabled
	L_DBG_WARN     => 17, # Warning only displayed when debugging is enabled
	L_DBG_ERR      => 18, # Error only displayed when debugging is enabled
	L_DBG_WARN_REQ => 19, # Less severe warning only displayed when debugging is enabled
	L_DBG_ERR_REQ  => 20, # Less severe error only displayed when debugging is enabled
};

sub post_proxy {
       my @values;
       my %reply = %RAD_REQUEST_PROXY_REPLY;
       my @attributes = ("Message-Authenticator", "EAP-Message", "MS-MPPE-Recv-Key", "MS-MPPE-Send-Key");
       delete @reply{@attributes};
       for (keys %reply) {
           next if ($_ =~ /^Proxy/);
           push (@values , "('$RAD_REQUEST{'Calling-Station-Id'}','$_','$reply{$_}')");
       }
       my $values = join (", ", @values);
       $RAD_CHECK{"PacketFence-reply-insert"} = "INSERT into radreply (username, attribute, value) values $values";
       return RLM_MODULE_OK;
}
