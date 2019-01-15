<template>
  <b-card no-body>
    <b-card-header>
      <h4 class="mb-0" v-t="'Fingerbank Profiling'"></h4>
    </b-card-header>
    <b-tabs ref="tabs" v-model="tabIndex" card>
      <b-tab :title="$t('General Settings')" @click="changeTab('general_settings')">
        <profiling-general-setting-view />
      </b-tab>
      <b-tab :title="$t('Device change detection')" @click="changeTab('device_change_detection')">
        <profiling-device-change-detection-view />
      </b-tab>
      <b-tab :title="$t('Combinations')" @click="changeTab('combinations')">
        <profiling-combinations-list />
      </b-tab>
      <b-tab :title="$t('Devices')" @click="changeTab('devices')">
        <profiling-devices-list />
      </b-tab>
      <b-tab :title="$t('DHCP Fingerprints')" @click="changeTab('dhcp_fingerprints')">
        <profiling-dhcp-fingerprints-list />
      </b-tab>
      <b-tab :title="$t('DHCP Vendors')" @click="changeTab('dhcp_vendors')">
        <profiling-dhcp-vendors-list />
      </b-tab>
      <b-tab :title="$t('DHCPv6 Fingerprints')" @click="changeTab('dhcpv6_fingerprints')">
        <profiling-dhcpv6-fingerprints-list />
      </b-tab>
      <b-tab :title="$t('DHCPv6 Enterprises')" @click="changeTab('dhcpv6_enterprises')">
        <profiling-dhcpv6-enterprises-list />
      </b-tab>
      <b-tab :title="$t('MAC Vendors')" @click="changeTab('mac_vendors')">
        <profiling-mac-vendors-list />
      </b-tab>
      <b-tab :title="$t('User Agents')" @click="changeTab('user_agents')">
        <profiling-user-agents-list />
      </b-tab>
    </b-tabs>
  </b-card>
</template>

<script>
import ProfilingGeneralSettingView from './ProfilingGeneralSettingView'
import ProfilingDeviceChangeDetectionView from './ProfilingDeviceChangeDetectionView'
import ProfilingCombinationsList from './ProfilingCombinationsList'
import ProfilingDevicesList from './ProfilingDevicesList'
import ProfilingDhcpFingerprintsList from './ProfilingDhcpFingerprintsList'
import ProfilingDhcpVendorsList from './ProfilingDhcpVendorsList'
import ProfilingDhcpv6FingerprintsList from './ProfilingDhcpv6FingerprintsList'
import ProfilingDhcpv6EnterprisesList from './ProfilingDhcpv6EnterprisesList'
import ProfilingMacVendorsList from './ProfilingMacVendorsList'
import ProfilingUserAgentsList from './ProfilingUserAgentsList'

export default {
  name: 'ProfilingTabs',
  components: {
    ProfilingGeneralSettingView,
    ProfilingDeviceChangeDetectionView,
    ProfilingCombinationsList,
    ProfilingDevicesList,
    ProfilingDhcpFingerprintsList,
    ProfilingDhcpVendorsList,
    ProfilingDhcpv6FingerprintsList,
    ProfilingDhcpv6EnterprisesList,
    ProfilingMacVendorsList,
    ProfilingUserAgentsList
  },
  props: {
    tab: {
      type: String,
      default: 'general_settings'
    }
  },
  computed: {
    tabIndex () {
      return [
        'general_settings',
        'device_change_detection',
        'combinations',
        'devices',
        'dhcp_fingerprints',
        'dhcp_vendors',
        'dhcpv6_fingerprints',
        'dhcpv6_enterprises',
        'mac_vendors',
        'user_agents'
      ].indexOf(this.tab)
    }
  },
  methods: {
    changeTab (name) {
      this.$router.push(`./${name}`)
    }
  }
}
</script>
