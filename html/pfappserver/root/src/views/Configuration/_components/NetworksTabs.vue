<template>
  <b-card no-body>
    <b-card-header>
      <h4 class="mb-0" v-t="'Networks'"></h4>
    </b-card-header>
    <b-tabs ref="tabs" v-model="tabIndex" card lazy>
      <b-tab :title="$t('Network Settings')" @click="changeTab('network')">
        <network-view />
      </b-tab>
      <b-tab :title="$t('Interfaces')" @click="changeTab('interfaces')">
        <interfaces-list />
      </b-tab>
      <b-tab :title="$t('Inline')" @click="changeTab('inline')">
        <inline-view />
      </b-tab>
      <b-tab :title="$t('Inline Traffic Shaping')" @click="changeTab('traffic_shapings')">
        <traffic-shaping-policies-search />
      </b-tab>
      <b-tab :title="$t('Fencing')" @click="changeTab('fencing')">
        <fencing-view />
      </b-tab>
      <b-tab :title="$t('Device Parking')" @click="changeTab('parking')">
        <parking-view />
      </b-tab>
    </b-tabs>
  </b-card>
</template>

<script>
import NetworkView from '../networks/network/_components/TheView'
import InterfacesList from './InterfacesList'
import InlineView from '../networks/inline/_components/TheView'
import TrafficShapingPoliciesSearch from '../networks/trafficShapingPolicies/_components/TheSearch'
import FencingView from '../networks/fencing/_components/TheView'
import ParkingView from '../networks/parking/_components/TheView'

export default {
  name: 'networks-tabs',
  components: {
    NetworkView,
    InterfacesList,
    InlineView,
    TrafficShapingPoliciesSearch,
    FencingView,
    ParkingView
  },
  props: {
    storeName: {
      type: String
    },
    tab: {
      type: String,
      default: 'network'
    }
  },
  computed: {
    tabIndex: {
      get () {
        return ['network', 'interfaces', 'inline', 'traffic_shapings', 'fencing', 'parking'].indexOf(this.tab)
      },
      set () {
        // noop
      }
    }
  },
  methods: {
    changeTab (name) {
      this.$router.push({ name })
    }
  }
}
</script>
