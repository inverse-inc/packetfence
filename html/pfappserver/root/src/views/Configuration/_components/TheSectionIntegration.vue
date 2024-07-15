<template>
    <b-container>
        <h4>
            <icon class="mr-2" name="puzzle-piece" scale="1.5"></icon>
            {{ $t('Integration') }}
        </h4>
        <p v-t="'PacketFence integrates with many 3rd party solutions. Among the solutions, there are:'"></p>
        <dl>
            <dt v-t="'Event Handlers:'"></dt> <dd v-t="'PacketFence can receive security event information from multiple solutions over syslog. You can configure which data input you want to accept from this module.'"></dd>
            <dt v-t="'Firewall SSO:'"></dt> <dd v-t="'This allows PacketFence to let the firewall know who is using a particular IP address on the network. The firewall can then apply per-user or per-role policies.'"></dd>
            <dt v-t="'Web Services:'"></dt> <dd v-t="'This allows PacketFence to expose some of its APIs through Web Services. See the PacketFence Developers Guide for API documentation.'"></dd>
            <dt v-t="'Switch Templates:'"></dt> <dd v-t="'PacketFence supports a wide range of networking equipment. From this module, you can also support any standards-compliant networking equipment by creating an associated switch template for it and use it after in PacketFence to secure wired or WiFi accesses.'"></dd>
            <dt v-t="'Syslog Forwarding:'"></dt> <dd v-t="'From this module, you can configure PacketFence to send syslog-based information to remote syslog servers like SIEM-based solutions.'"></dd>
            <dt v-t="'WRIX:'"></dt> <dd v-t="'This allows PacketFence to define Wireless Roaming Intermediary eXchange (WRIX) information on access points it manages.'"></dd>
            <dt v-t="'PKI:'"></dt> <dd v-t="'PacketFence integrates a fully-featured Public Key Infrastructure (PKI) solution allowing you to manage certificates for EAP-TLS clients.'"></dd>
        </dl>
    </b-container>
</template>
