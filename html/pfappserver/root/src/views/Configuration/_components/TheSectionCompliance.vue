<template>
    <b-container>
        <h4>
            <icon class="mr-2" name="shield-alt" scale="1.5"></icon>
            {{ $t('Compliance') }}
        </h4>
        <p v-t="'PacketFence can ensure a high-level of security on your network by enforcing compliance of your acceptable use policy. The compliance modules are:'"></p>
        <dl>
            <dt v-t="'Fingerbank Profile:'"></dt> <dd v-t="'This is for device profiling or fingerprinting using the Fingerbank solution. Fingerbank allows you to accurately identify an endpoint on your network (printer vs. tablet).'"></dd>
            <dt v-t="'Network Anomaly Detection:'"></dt> <dd v-t="'Together with Fingerbank, PacketFence is able to detect abnormal network activity of devices on your network. You can create here templates of what you consider abnormal on your network so PacketFence can react based on this through its Security Events.'"></dd>
            <dt v-t="'Scans:'"></dt> <dd v-t="'PacketFence can use active vulnerability like Nessus or OpenVAS to proactively scan endpoints for security problems. You can define the scanners being used here.'"></dd>
            <dt v-t="'Security Events:'"></dt> <dd v-t="'This powerful module allows you to tie security events (malware detection, unauthorized operating system, etc.) with actions such as quarantining endpoints, sending email alerts and showing remediation instructions from captive portal.'"></dd>
        </dl>
    </b-container>
</template>
