<template>
    <b-container>
        <h4>
            <icon class="mr-2" name="cogs" scale="1.5"></icon>
            {{ $t('System Configuration') }}
        </h4>
        <p v-t="'PacketFence allows you to perform advanced system configuration. Among the configuration options, there are:'"></p>
        <dl>
            <dt v-t="'Main Configuration:'"></dt> <dd v-t="'General PacketFence configuration parameters can be changed from this module.'"></dd>
            <dt v-t="'Database:'"></dt> <dd v-t="'PacketFence makes use of a MySQL/MariaDB database. You can configure the connection information from this module.'"></dd>
            <dt v-t="'Cluster:'"></dt> <dd v-t="'PacketFence supports clustering of 3+ members. You can configure the clustering solution from this module.'"></dd>
            <dt v-t="'RADIUS Configuration:'"></dt> <dd v-t="'EAP methods provided by PacketFence can be changed and the RADIUS auditing feature can be enabled or not from this module.'"></dd>
            <dt v-t="'DNS Configuration:'"></dt> <dd v-t="'The DNS auditing feature can be enabled or not from this module.'"></dd>
            <dt v-t="'Admin Access:'"></dt> <dd v-t="'Different access level can be defined for the PacketFence administrative interface from this module.'"></dd>
            <dt v-t="'SSL Certificates:'"></dt> <dd v-t="'This section allows you to manage your captive-portal and RADIUS certificates.'"></dd>
        </dl>
    </b-container>
</template>
