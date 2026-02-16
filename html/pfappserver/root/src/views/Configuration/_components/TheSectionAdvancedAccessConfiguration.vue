<template>
    <b-container>
        <h4>
            <icon class="mr-2" name="clipboard-list" scale="1.5"></icon>
            {{ $t('Advanced Access Configuration') }}
        </h4>
        <p v-t="'Access control decisions in PacketFence can be fine-tuned through advanced parameters. Among them:'"></p>
        <dl>
            <dt v-t="'Captive Portal:'"></dt>
            <dd v-t="'Global captive portal parameters can be configured from this module.'"></dd>
            <dt v-t="'Filter Engines:'"></dt>
            <dd v-t="'Filter engines allow you to create advanced filtering rules based on RADIUS, DHCP, DNS, or HTTP information, as well as define advanced role-mapping or VLAN-mapping rules.'"></dd>
            <dt v-t="'Billing Tiers:'"></dt>
            <dd v-t="'Billing tiers define pricing levels for billing engine integrations.'"></dd>
            <dt v-t="'PKI Providers:'"></dt>
            <dd v-t="'When provisioning with EAP-TLS, PacketFence must be configured to integrate with a PKI infrastructure. Configure PKI providers from this module.'"></dd>
            <dt v-t="'Provisioners:'"></dt>
            <dd v-t="'Provisioners push provisioning agents to endpoints to auto-configure WiFi connections during the registration process.'"></dd>
            <dt v-t="'Portal Modules:'"></dt>
            <dd v-t="'Portal modules allow you to deeply customize captive portal workflows.'"></dd>
            <dt v-t="'Access Duration:'"></dt>
            <dd v-t="'Access durations define the time-based access options available in action definitions from your authentication sources.'"></dd>
            <dt v-t="'Self Service Portal:'"></dt>
            <dd v-t="'The self-service portal allows users to manually register endpoints and manage their registered devices. A self-service policy must be associated with a connection profile.'"></dd>
        </dl>
    </b-container>
</template>
