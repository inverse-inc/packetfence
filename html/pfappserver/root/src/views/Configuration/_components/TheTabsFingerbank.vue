<template>
  <b-card no-body>
    <b-card-header>
      <h4 class="mb-3" v-t="'Fingerbank Profiling'"></h4>
      <b-button class="mb-1" size="sm" variant="outline-primary" :disabled="isUpdateDatabaseLoading" @click="updateDatabase()">
        <icon class="mr-1" name="sync" :spin="isUpdateDatabaseLoading"></icon>
        {{ $t('Update Fingerbank Database') }}
      </b-button>
    </b-card-header>
    <b-tabs ref="tabs" v-model="tabIndex" card lazy>
      <b-tab v-for="(tab, index) in tabs" :key="index"
        :title="$t(tab.title)" @click="tabIndex = index">
        <component :is="tab.component" v-bind="('props' in tab) ? tab.props($props) : {}"/>
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

const tabs = {
  fingerbankGeneralSettings: {
    title: 'General Settings', // i18n defer
    component: FingerbankGeneralSettingView
  },
  fingerbankDeviceChangeDetection: {
    title: 'Device change detection', // i18n defer
    component: FingerbankDeviceChangeDetectionView
  },
  fingerbankCombinations: {
    title: 'Combinations', // i18n defer
    component: FingerbankCombinationsSearch
  },
  fingerbankDevicesByScope: {
    title: 'Devices', // i18n defer
    component: FingerbankDevicesSearch,
    props: ({ parentId, scope }) => ({ parentId, scope })
  },
  fingerbankDhcpFingerprintsByScope: {
    title: 'DHCP Fingerprints', // i18n defer
    component: FingerbankDhcpFingerprintsSearch,
    props: ({ scope }) => ({ scope })
  },
  fingerbankDhcpVendorsByScope: {
    title: 'DHCP Vendors', // i18n defer
    component: FingerbankDhcpVendorsSearch,
    props: ({ scope }) => ({ scope })
  },
  fingerbankDhcpv6FingerprintsByScope: {
    title: 'DHCPv6 Fingerprints', // i18n defer
    component: FingerbankDhcpv6FingerprintsSearch,
    props: ({ scope }) => ({ scope })
  },
  fingerbankDhcpv6EnterprisesByScope: {
    title: 'DHCPv6 Enterprises', // i18n defer
    component: FingerbankDhcpv6EnterprisesSearch,
    props: ({ scope }) => ({ scope })
  },
  fingerbankMacVendorsByScope: {
    title: 'MAC Vendors', // i18n defer
    component: FingerbankMacVendorsSearch,
    props: ({ scope }) => ({ scope })
  },
  fingerbankUserAgentsByScope: {
    title: 'User Agents', // i18n defer
    component: FingerbankUserAgentsSearch,
    props: ({ scope }) => ({ scope })
  }
}

const props = {
  tab: {
    type: String,
    default: Object.keys(tabs)[0]
  },
  parentId: {
    type: String
  },
  scope: {
    type: String,
    default: 'all'
  }
}

import { computed, customRef, toRefs } from '@vue/composition-api'

const setup = (props, context) => {

  const {
    tab
  } = toRefs(props)

  const { root: { $store, $router } = {} } = context

  const tabIndex = customRef((track, trigger) => ({
    get() {
      track()
      return Object.keys(tabs).indexOf(tab.value)
    },
    set(newValue) {
      $router.push({ name: Object.keys(tabs)[newValue] })
        .catch(e => { if (e.name !== "NavigationDuplicated") throw e })
      trigger()
    }
  }))

  const isUpdateDatabaseLoading = computed(() => $store.getters['$_fingerbank/isUpdateDatabaseLoading'])

  const updateDatabase = () => $store.dispatch('$_fingerbank/updateDatabase')

  return {
    tabs,
    tabIndex,
    isUpdateDatabaseLoading,
    updateDatabase
  }
}

// @vue/component
export default {
  name: 'the-tabs-fingerbank',
  props,
  setup
}
</script>
