<template>
    <div>
        <h4 v-t="'Compliance'"></h4>
        <p v-t="'PacketFence can ensure a high-level of security on your network by enforcing compliance of your acceptable use policy. The compliance modules are:'"></p>
        <dl>
            <dt v-t="'Fingerbank Profile:'"></dt> <dd>This is for device profiling or fingerprinting using the Fingerbank solution. Fingerbank allows you to accurately identify an endpoint on your network (printer vs. tablet).</dd>
            <dt v-t="'Scans:'"></dt> <dd>PacketFence can use active vulnerability like Nessus, OpenVAS or Windows Management Instrumentation (WMI) to proactively scan endpoints for security problems. You can define the scanners being used here.</dd>
            <dt v-t="'Violations:'"></dt> <dd>This powerful module allows you to tie security events (malware detection, unauthorized operating system, etc.) with actions such as quarantining endpoints, sending email alerts and showing remediation instructions from captive portal.</dd>
        </dl>
    </div>
</template>
