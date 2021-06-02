<template>
  <b-card no-body>
    <b-card-header>
      <h4 class="mb-3" v-t="'Fingerbank Profiling'"></h4>
      <b-button class="mb-1" size="sm" variant="outline-primary" :disabled="isUpdateDatabaseLoading" @click="updateDatabase()">
        <icon class="mr-1" name="sync" :spin="isUpdateDatabaseLoading"></icon>
        {{ $t('Update Fingerbank Database') }}
      </b-button>
    </b-card-header>
    <b-tabs ref="tabs" v-model="tabIndex" card>
      <b-tab :title="$t('General Settings')" @click="changeTab('general_settings')">
        <fingerbank-general-setting-view />
      </b-tab>
      <b-tab :title="$t('Device change detection')" @click="changeTab('device_change_detection')">
        <fingerbank-device-change-detection-view />
      </b-tab>
      <b-tab :title="$t('Combinations')" @click="changeTab('combinations')">
        <fingerbank-combinations-search />
      </b-tab>
      <b-tab :title="$t('Devices')" @click="changeTab('devices')">
        <fingerbank-devices-search :parentId="parentId" :scope="scope" />
      </b-tab>
      <b-tab :title="$t('DHCP Fingerprints')" @click="changeTab('dhcp_fingerprints')">
        <fingerbank-dhcp-fingerprints-search :scope="scope" />
      </b-tab>
      <b-tab :title="$t('DHCP Vendors')" @click="changeTab('dhcp_vendors')">
        <fingerbank-dhcp-vendors-search :scope="scope" />
      </b-tab>
      <b-tab :title="$t('DHCPv6 Fingerprints')" @click="changeTab('dhcpv6_fingerprints')">
        <fingerbank-dhcpv6-fingerprints-search :scope="scope" />
      </b-tab>
      <b-tab :title="$t('DHCPv6 Enterprises')" @click="changeTab('dhcpv6_enterprises')">
        <fingerbank-dhcpv6-enterprises-search :scope="scope" />
      </b-tab>
      <b-tab :title="$t('MAC Vendors')" @click="changeTab('mac_vendors')">
        <fingerbank-mac-vendors-search :scope="scope" />
      </b-tab>
      <b-tab :title="$t('User Agents')" @click="changeTab('user_agents')">
        <fingerbank-user-agents-search :scope="scope" />
      </b-tab>
    </b-tabs>
  </b-card>
</template>

<script>
import FingerbankGeneralSettingView from '../fingerbank/generalSettings/_components/TheView'
import FingerbankDeviceChangeDetectionView from '../fingerbank/deviceChangeDetection/_components/TheView'
import FingerbankCombinationsSearch from '../fingerbank/combinations/_components/TheSearch'
import FingerbankDevicesSearch from '../fingerbank/devices/_components/TheSearch'
import FingerbankDhcpFingerprintsSearch from '../fingerbank/dhcpFingerprints/_components/TheSearch'
import FingerbankDhcpVendorsSearch from '../fingerbank/dhcpVendors/_components/TheSearch'
import FingerbankDhcpv6FingerprintsSearch from '../fingerbank/dhcpv6Fingerprints/_components/TheSearch'
import FingerbankDhcpv6EnterprisesSearch from '../fingerbank/dhcpv6Enterprises/_components/TheSearch'
import FingerbankMacVendorsSearch from '../fingerbank/macVendors/_components/TheSearch'
import FingerbankUserAgentsSearch from '../fingerbank/userAgents/_components/TheSearch'

export default {
  name: 'fingerbank-tabs',
  components: {
    FingerbankGeneralSettingView,
    FingerbankDeviceChangeDetectionView,
    FingerbankCombinationsSearch,
    FingerbankDevicesSearch,
    FingerbankDhcpFingerprintsSearch,
    FingerbankDhcpVendorsSearch,
    FingerbankDhcpv6FingerprintsSearch,
    FingerbankDhcpv6EnterprisesSearch,
    FingerbankMacVendorsSearch,
    FingerbankUserAgentsSearch
  },
  props: {
    tab: {
      type: String,
      default: 'general_settings'
    },
    parentId: {
      type: String,
      default: null
    },
    scope: {
      type: String,
      default: 'all'
    }
  },
  computed: {
    tabIndex: {
      get () {
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
      },
      set () {
        // noop
      }
    },
    isUpdateDatabaseLoading () {
      return this.$store.getters['$_fingerbank/isUpdateDatabaseLoading']
    }
  },
  methods: {
    changeTab (path) {
      switch (path) {
        case 'devices':
        case 'dhcp_fingerprints':
        case 'dhcp_vendors':
        case 'dhcpv6_fingerprints':
        case 'dhcpv6_enterprises':
        case 'mac_vendors':
        case 'user_agents':
          this.$router.push(`/configuration/fingerbank/${this.scope}/${path}`)
          break
        default:
          this.$router.push(`/configuration/fingerbank/${path}`)
          break
      }
    },
    updateDatabase () {
      this.$store.dispatch('$_fingerbank/updateDatabase')
    }
  }
}
</script>
