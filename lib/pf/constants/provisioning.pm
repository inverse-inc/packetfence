package pf::constants::provisioning;

use base qw(Exporter);
our @EXPORT_OK = qw(
    $SENTINEL_ONE_TOKEN_EXPIRY
);

use Readonly;

=item $SENTINEL_ONE_TOKEN_EXPIRY

Amount of seconds a Sentinel one token is valid (1 hour)

=cut

Readonly our $SENTINEL_ONE_TOKEN_EXPIRY => 60*60;
