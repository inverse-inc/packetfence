<template>
    <b-container>
        <h4>
            <icon class="mr-2" name="puzzle-piece" scale="1.5"></icon>
            {{ $t('Integration') }}
        </h4>
        <p v-t="'PacketFence integrates with many 3rd party solutions. Among the solutions, there are:'"></p>
        <dl>
            <dt v-t="'Firewall SSO:'"></dt> <dd v-t="'This allows PacketFence to let the firewall know who is using a particular IP address on the network. The firewall can then apply per-user or per-role policies.'"></dd>
            <dt v-t="'Cisco Mobility Services Engine:'"></dt> <dd v-t="'This provides PacketFence geographical location information of endpoints on the network. You can then provide a different captive portal based on where the device is physically located, or position an endpoint on a specific map of a building.'"></dd>
            <dt v-t="'Web Services:'"></dt> <dd v-t="'This allows PacketFence to expose some of its APIs through Web Services. See the PacketFence Developers Guide for API documentation.'"></dd>
            <dt v-t="'Syslog Parsers:'"></dt> <dd v-t="'PacketFence can receive security event information from multiple solutions over syslog. You can configure which data input you want to accept from this module.'"></dd>
            <dt v-t="'WRIX:'"></dt> <dd v-t="'This allows PacketFence to define Wireless Roaming Intermediary eXchange (WRIX) information on access points it manages.'"></dd>
        </dl>
    </b-container>
</template>
