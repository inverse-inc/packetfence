<template>
    <b-container>
        <h4>
            <icon class="mr-2" name="id-card" scale="1.5"></icon>
            {{ $t('Policies and Access Control') }}
        </h4>
        <p v-t="'When an endpoint connects to the network, PacketFence must be able to assign a role to it, or its user. The role can then be translated to a VLAN, a set of ACL, a switch manufacturer policy identifier or a combinations of all of this.'"></p>
        <p v-t="'For PacketFence to work properly, you must define in the following order:'"></p>

        <dl>
            <dt v-t="'Roles:'"></dt> <dd v-t="'A role will allow PacketFence to grant different network access to endpoints connecting to your network. For example, employee vs. guest.'"></dd>
            <dt v-t="'Domains:'"></dt> <dd v-t="'If you want to authenticate users or machines using a Active Directory Domain Controller (DC), you have to join the PacketFence server to the DC.'"></dd>
            <dt v-t="'Sources:'"></dt> <dd v-t="'Authentication sources will allow you to identify users and assign them roles and access durations.'"></dd>
            <dt v-t="'Switches:'"></dt> <dd v-t="'PacketFence manages switches, access points and WiFi controllers. You have to add the equipment you want PacketFence to manage and do the role by VLAN/ACL/policy identifier mapping.'"></dd>
            <dt v-t="'Connection Profiles:'"></dt> <dd v-t="'When devices are connecting to your network, you might want to show a captive portal or auto-register the device. You can control the behavior in this module.'"></dd>
        </dl>
    </b-container>
</template>
