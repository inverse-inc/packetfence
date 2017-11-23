package pf::tenant_code;

=head1 NAME

pf::tenant_code

=head1 DESCRIPTION

Allows onboarding of tenants using a unique code

=cut

use strict;
use warnings;

use pf::error qw(is_success is_error);
use pf::constants qw($TRUE $FALSE);
use pf::tenant;
use pf::dal::tenant;
use pf::dal::tenant_code;
use pf::log;
use pf::ConfigStore::Switch;

sub onboard {
    my ($proto, $code, $tenant_info) = @_;
    my $logger = get_logger;

    my $status;

    ($status, my $tenant_code) = pf::dal::tenant_code->find({ code => $code }, -no_auto_tenant_id => $TRUE);
    if(is_error($status)) {
        $logger->info("Impossible to find code $code");
        return $FALSE;
    }

    my $tenant = pf::dal::tenant->search(-where => {
        name => $tenant_info->{name},
    })->next;

    if($tenant) {
        $logger->info("Onboarding an existing tenant. Will add the switch attached to this code to tenant $tenant->{name}");
    }
    else {
        $logger->info("Onboarding a new tenant with username $tenant_info->{name}");
        $status = pf::tenant::tenant_add($tenant_info);
        if(!$status) {
            $logger->error("Impossible to create tenant with tenant name $tenant_info->{name}");
            return $FALSE;
        }

        $tenant = pf::dal::tenant->search(-where => {
            name => $tenant_info->{name},
        })->next;

    }

    my $cs  = pf::ConfigStore::Switch->new;
    $cs->update_or_create($tenant_code->{switch_ip}, {TenantId => $tenant->{id}});
    my ($result, $msg) = $cs->commit();

    if(!$result) {
        $logger->error("Impossible to perform tenant switch modification for $tenant_code->{switch_ip}. Error was: $msg");
        return $FALSE;
    }
}

1;
