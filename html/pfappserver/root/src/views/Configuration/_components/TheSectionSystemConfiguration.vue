<template>
    <b-container>
        <h4>
            <icon class="mr-2" name="cogs" scale="1.5"></icon>
            {{ $t('System Configuration') }}
        </h4>
        <p v-t="'PacketFence allows you to perform advanced system configuration. Among the configuration options:'"></p>
        <dl>
            <dt v-t="'Main Configuration:'"></dt>
            <dd v-t="'General PacketFence configuration parameters including alerting, advanced settings, maintenance tasks, and service management.'"></dd>
            <dt v-t="'Database:'"></dt>
            <dd v-t="'PacketFence uses a MySQL/MariaDB database. Configure general and advanced database settings, as well as ProxySQL, from this module.'"></dd>
            <dt class="no-saas" v-t="'Cluster:'"></dt>
            <dd class="no-saas" v-t="'PacketFence supports clustering of 3 or more members. Configure the clustering solution from this module.'"></dd>
            <dt v-t="'Connectors:'"></dt>
            <dd v-t="'Connectors extend PacketFence capabilities to remote sites, providing domain join and DNS resolution services.'"></dd>
            <dt v-t="'RADIUS:'"></dt>
            <dd v-t="'Configure RADIUS settings including EAP, TLS, FAST, and OCSP profiles, as well as PKI SSL certificates used by the RADIUS service.'"></dd>
            <dt v-t="'Admin Access:'"></dt>
            <dd v-t="'Define different access levels for the PacketFence administrative interface.'"></dd>
            <dt v-t="'Admin Login:'"></dt>
            <dd v-t="'Configure the authentication sources and settings used for administrator login to the PacketFence interface.'"></dd>
            <dt v-t="'DNS Configuration:'"></dt>
            <dd v-t="'Configure DNS auditing and DNS-related features from this module.'"></dd>
            <dt class="no-saas" v-t="'FleetDM:'"></dt>
            <dd class="no-saas" v-t="'Configure FleetDM integration settings for endpoint posture and compliance data.'"></dd>
            <dt v-t="'Kafka:'"></dt>
            <dd v-t="'Configure Kafka integration for streaming event data to external consumers.'"></dd>
            <dt v-t="'SSL Certificates:'"></dt>
            <dd v-t="'Manage captive portal and RADIUS SSL certificates from this module.'"></dd>
        </dl>
    </b-container>
</template>
