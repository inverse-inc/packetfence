=item returnRadiusAccessAccept

Overloading L<pf::Switch>'s implementation because AeroHIVE doesn't support
assigning VLANs and Roles at the same time.

=cut

sub returnRadiusAccessAccept {
    my ($self, $args) = @_;
    my $logger = $self->logger;

    my $radius_reply_ref = {};
    my $status;
    # should this node be kicked out?
    my $kick = $self->handleRadiusDeny($args);
    return $kick if (defined($kick));

    $logger->debug("Network device (".$self->{'_id'}.") supports roles. Evaluating role to be returned.");
    if ( isenabled($self->{_RoleMap}) && $self->supportsRoleBasedEnforcement()) {
        my $role = $self->getRoleByName($args->{'user_role'});

        # Roles are configured and the user should have one
        if (defined($role) && $role ne ""  && isenabled($self->{_RoleMap})) {
            $radius_reply_ref = {
                'Tunnel-Medium-Type' => $RADIUS::IP,
                'Tunnel-Type' => $RADIUS::VLAN,
                'Filter-Id' => $role . "",
            };
        }

        $logger->info("(".$self->{'_id'}.") Returning ACCEPT with Role: $role");

    }

    # if Roles aren't configured, return VLAN information
    if (isenabled($self->{_VlanMap}) && defined($args->{'vlan'})) {
        $radius_reply_ref = {
             %$radius_reply_ref,
            'Tunnel-Medium-Type' => $RADIUS::ETHERNET,
            'Tunnel-Type' => $RADIUS::VLAN,
            'Tunnel-Private-Group-ID' => $args->{'vlan'} . "",
        };

        $logger->info("Returning ACCEPT with VLAN: $args->{'vlan'}");
    }

    my $filter = pf::access_filter::radius->new;
    my $rule = $filter->test('returnRadiusAccessAccept', $args);
    ($radius_reply_ref, $status) = $filter->handleAnswerInRule($rule,$args,$radius_reply_ref);
    return [$status, %$radius_reply_ref];

}
