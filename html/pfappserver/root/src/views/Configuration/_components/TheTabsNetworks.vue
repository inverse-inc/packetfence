<template>
  <b-card no-body>
    <b-card-header>
      <h4 class="mb-0" v-t="'Networks'"></h4>
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
import NetworkView from '../networks/network/_components/TheView'
import InterfacesList from '../networks/interfaces/_components/TheList'
import InlineView from '../networks/inline/_components/TheView'
import TrafficShapingPoliciesSearch from '../networks/trafficShapingPolicies/_components/TheSearch'
import FencingView from '../networks/fencing/_components/TheView'
import ParkingView from '../networks/parking/_components/TheView'

const tabs = {
  network: {
    title: 'Network Settings', // i18n defer
    component: NetworkView
  },
  interfaces: {
    title: 'Interfaces', // i18n defer
    component: InterfacesList
  },
  inline: {
    title: 'Inline', // i18n defer
    component: InlineView
  },
  traffic_shapings: {
    title: 'Inline Traffic Shaping', // i18n defer
    component: TrafficShapingPoliciesSearch
  },
  fencing: {
    title: 'Fencing', // i18n defer
    component: FencingView
  },
  parking: {
    title: 'Device Parking', // i18n defer
    component: ParkingView
  }
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
  name: 'the-tabs-networks',
  props,
  setup
}
</script>
