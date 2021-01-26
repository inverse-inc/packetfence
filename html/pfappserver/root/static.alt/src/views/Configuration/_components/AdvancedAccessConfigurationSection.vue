<template>
    <b-container>
        <h4>
            <icon class="mr-2" name="clipboard-list" scale="1.5"></icon>
            {{ $t('Advanced Access Configuration') }}
        </h4>
        <p v-t="'Access control decisions in PacketFence can be modified through advanced parameters. Among them, there are:'"></p>
        <dl>
            <dt v-t="'Captive Portal:'"></dt> <dd v-t="'This is for changing global captive-portal parameters.'"></dd>
            <dt v-t="'Filter Engines:'"></dt> <dd v-t="'PacketFence allows you to create advanced filtering rules based on RADIUS, DHCP, DNS or HTTP information. It also allows you to define advanced role-mapping or VLAN-mapping rules.'"></dd>
            <dt v-t="'Billing Tiers:'"></dt> <dd v-t="'This allows PacketFence to define tiers for billing engines integration.'"></dd>
            <dt v-t="'PKI Provider:'"></dt> <dd v-t="'When provisioning in EAP-TLS, PacketFence needs to be configured to integrate with PKI infrastructure. This is done in this module.'"></dd>
            <dt v-t="'Provisioners:'"></dt> <dd v-t="'PacketFence can push provisioning agents on endpoints to auto-configure the WiFi connection during the registration process. You can configure the provisioning agents in this module.'"></dd>
            <dt v-t="'Portal Modules:'"></dt> <dd v-t="'The module allows you to deeply customize the captive portal workflows.'"></dd>
            <dt v-t="'Access Duration:'"></dt> <dd v-t="'This allows you to set the various access duration that will be available in your actions definition from your authentication sources.'"></dd>
            <dt v-t="'Self Service:'"></dt> <dd v-t="'This allows you to enable the self service feature in PacketFence - which allows users to manually register endpoints from a portal page and manage their registered devices. A self service policy need to be associated to a connection profile.'"></dd>
        </dl>
    </b-container>
</template>
