<template>
    <b-container>
        <h4>
            <icon class="mr-2" name="puzzle-piece" scale="1.5"></icon>
            {{ $t('Integration') }}
        </h4>
        <p v-t="'PacketFence integrates with many third-party solutions. Among the integrations available:'"></p>
        <dl>
            <dt v-t="'Cloud Services:'"></dt>
            <dd v-t="'PacketFence can integrate with cloud service providers to extend network access control to cloud-managed environments.'"></dd>
            <dt v-t="'Event Loggers:'"></dt>
            <dd v-t="'Event loggers allow PacketFence to send structured event data to external logging and analytics platforms.'"></dd>
            <dt v-t="'Firewall SSO:'"></dt>
            <dd v-t="'Firewall SSO informs the firewall which user is behind a particular IP address on the network, allowing the firewall to apply per-user or per-role policies.'"></dd>
            <dt class="no-saas" v-t="'FleetDM:'"></dt>
            <dd class="no-saas" v-t="'FleetDM integration allows PacketFence to query endpoint posture and compliance data from FleetDM.'"></dd>
            <dt v-t="'Web Services:'"></dt>
            <dd v-t="'Web Services expose PacketFence APIs for external consumption. See the PacketFence Developers Guide for API documentation.'"></dd>
            <dt v-t="'Switch Templates:'"></dt>
            <dd v-t="'Switch templates allow you to support any standards-compliant networking equipment by creating a template to secure wired or WiFi access through PacketFence.'"></dd>
            <dt v-t="'Event Handlers:'"></dt>
            <dd v-t="'Event handlers allow PacketFence to receive security event information from multiple solutions over syslog. Configure which data inputs to accept from this module.'"></dd>
            <dt v-t="'Syslog Forwarding:'"></dt>
            <dd v-t="'Syslog forwarding sends PacketFence log data to remote syslog servers such as SIEM solutions.'"></dd>
            <dt v-t="'WRIX:'"></dt>
            <dd v-t="'WRIX defines Wireless Roaming Intermediary eXchange information on access points managed by PacketFence.'"></dd>
            <dt v-t="'PKI:'"></dt>
            <dd v-t="'PacketFence integrates a fully-featured Public Key Infrastructure (PKI) solution for managing certificates used by EAP-TLS clients.'"></dd>
            <dt v-t="'Multi-Factor Authentication:'"></dt>
            <dd v-t="'Multi-factor authentication (MFA) providers add an additional layer of security during the authentication process.'"></dd>
        </dl>
    </b-container>
</template>
