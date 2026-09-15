<template>
    <b-container>
        <h4>
            <icon class="mr-2" name="project-diagram" scale="1.5"></icon>
            {{ $t('Network Configuration') }}
        </h4>
        <p v-t="'PacketFence allows you to configure network-related settings. Among the configuration options:'"></p>
        <dl>
            <dt class="no-saas" v-t="'Networks:'"></dt>
            <dd class="no-saas" v-t="'Configure networks managed by PacketFence, including network settings, interfaces, inline mode, fencing parameters, and device parking.'"></dd>
            <dt v-t="'Connectors:'"></dt>
            <dd v-t="'Connectors extend PacketFence capabilities to remote sites, providing domain join and DNS resolution services.'"></dd>
            <dt class="no-saas" v-t="'SNMP:'"></dt>
            <dd class="no-saas" v-t="'Configure the SNMP traps engine used by PacketFence for switch and device communication.'"></dd>
            <dt class="no-saas" v-t="'Floating Devices:'"></dt>
            <dd class="no-saas" v-t="'Floating devices are network devices such as switches that move between locations. PacketFence automatically reconfigures switch ports when a floating device is connected.'"></dd>
        </dl>
    </b-container>
</template>
