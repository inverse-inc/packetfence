<template>
  <b-card no-body>
    <b-card-header>
      <h4 class="mb-0">
        {{ $t('Network Devices') }}
        <base-button-help class="text-black-50 ml-1" url="PacketFence_Installation_Guide.html#_network_devices_definition_switches_conf" />
      </h4>
    </b-card-header>
    <b-tabs ref="tabs" v-model="tabIndex" card lazy>
      <b-tab v-for="(tab, index) in tabs" :key="index"
        :title="$t(tab.title)" @click="tabIndex = index">
        <component :is="tab.component" />
      </b-tab>
    </b-tabs>
  </b-card>
</template>

<script>
import SwitchesSearch from '../switches/_components/TheSearch'
import SwitchGroupsSearch from '../switchGroups/_components/TheSearch'

const tabs = {
  switches: {
    title: 'Switches', // i18n defer
    component: SwitchesSearch
  },
  switch_groups: {
    title: 'Switch Groups', // i18n defer
    component: SwitchGroupsSearch
  }
}

import {
  BaseButtonHelp
} from '@/components/new/'

const components = {
  BaseButtonHelp
}

const props = {
  tab: {
    type: String,
    default: Object.keys(tabs)[0]
  }
}

import { customRef, toRefs } from '@vue/composition-api'

const setup = (props, context) => {

  const {
    tab
  } = toRefs(props)

  const { root: { $router } = {} } = context

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

  return {
    tabs,
    tabIndex
  }
}

// @vue/component
export default {
  name: 'the-tabs-network-devices',
  components,
  props,
  setup
}
</script>
