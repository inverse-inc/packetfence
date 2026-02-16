<template>
    <b-container>
        <h4>
            <icon class="mr-2" name="id-card" scale="1.5"></icon>
            {{ $t('Policies and Access Control') }}
        </h4>
        <p v-t="'When an endpoint connects to the network, PacketFence assigns a role to it or its user. The role is then translated to a VLAN, a set of ACLs, a vendor-specific policy identifier, or a combination of these.'"></p>
        <p v-t="'For PacketFence to work properly, configure in the following order:'"></p>

        <dl>
            <dt v-t="'Roles:'"></dt>
            <dd v-t="'Roles allow PacketFence to grant different levels of network access to endpoints. For example, differentiating between employee and guest access.'"></dd>
            <dt class="no-saas" v-t="'Active Directory Domains:'"></dt>
            <dd class="no-saas" v-t="'To authenticate users or machines against an Active Directory Domain Controller (DC), the PacketFence server must be joined to the domain.'"></dd>
            <dt v-t="'Realms:'"></dt>
            <dd v-t="'Realms allow you to define RADIUS realms and map them to domains and authentication sources.'"></dd>
            <dt v-t="'Authentication Sources:'"></dt>
            <dd v-t="'Authentication sources identify users and assign them roles and access durations.'"></dd>
            <dt v-t="'Network Devices:'"></dt>
            <dd v-t="'PacketFence manages switches, access points, and WiFi controllers. Add the equipment you want PacketFence to manage and configure the role-to-VLAN, ACL, and policy identifier mappings. Switch groups allow you to apply shared configurations across multiple devices.'"></dd>
            <dt v-t="'Connection Profiles:'"></dt>
            <dd v-t="'Connection profiles control the behavior when devices connect to your network, such as displaying a captive portal or auto-registering the device.'"></dd>
        </dl>
    </b-container>
</template>
