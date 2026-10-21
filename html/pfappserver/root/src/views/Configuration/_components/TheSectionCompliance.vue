<template>
    <b-container>
        <h4>
            <icon class="mr-2" name="shield-alt" scale="1.5"></icon>
            {{ $t('Compliance') }}
        </h4>
        <p v-t="'PacketFence enforces a high level of security on your network through compliance with your acceptable use policy. The compliance modules are:'"></p>
        <dl>
            <dt v-t="'Fingerbank Profiling:'"></dt>
            <dd v-t="'Fingerbank accurately identifies endpoints on your network through device profiling and fingerprinting, distinguishing between device types such as printers and tablets.'"></dd>
            <dt v-t="'Network Anomaly Detection:'"></dt>
            <dd v-t="'Together with Fingerbank, PacketFence detects abnormal network activity from devices on your network. Define templates for what constitutes abnormal behavior so PacketFence can react through Security Events.'"></dd>
            <dt v-t="'Scan Engines:'"></dt>
            <dd v-t="'PacketFence can use active vulnerability scanners like Nessus or OpenVAS to proactively scan endpoints for security problems. Define the scan engines to use from this module.'"></dd>
            <dt v-t="'Security Events:'"></dt>
            <dd v-t="'Security events tie triggers (malware detection, unauthorized operating system, etc.) to actions such as quarantining endpoints, sending email alerts, and showing remediation instructions on the captive portal.'"></dd>
        </dl>
    </b-container>
</template>
