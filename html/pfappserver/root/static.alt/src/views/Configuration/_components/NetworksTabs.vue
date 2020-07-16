<template>
  <b-card no-body>
    <b-card-header>
      <h4 class="mb-0" v-t="'Networks'"></h4>
    </b-card-header>
    <b-tabs ref="tabs" v-model="tabIndex" card>
      <b-tab :title="$t('Network Settings')" @click="changeTab('network')">
        <network-view form-store-name="formNetwork" />
      </b-tab>
      <b-tab :title="$t('Interfaces')" @click="changeTab('interfaces')">
        <interfaces-list />
      </b-tab>
      <b-tab :title="$t('Inline')" @click="changeTab('inline')">
        <inline-view form-store-name="formInline" />
      </b-tab>
      <b-tab :title="$t('Inline Traffic Shaping')" @click="changeTab('traffic_shapings')">
        <traffic-shapings-list />
      </b-tab>
      <b-tab :title="$t('Fencing')" @click="changeTab('fencing')">
        <fencing-view form-store-name="formFencing" />
      </b-tab>
      <b-tab :title="$t('Device Parking')" @click="changeTab('parking')">
        <parking-view form-store-name="formParking" />
      </b-tab>
    </b-tabs>
  </b-card>
</template>

<script>
import FormStore from '@/store/base/form'
import NetworkView from './NetworkView'
import InterfacesList from './InterfacesList'
import InlineView from './InlineView'
import TrafficShapingsList from './TrafficShapingsList'
import FencingView from './FencingView'
import ParkingView from './ParkingView'

export default {
  name: 'networks-tabs',
  components: {
    NetworkView,
    InterfacesList,
    InlineView,
    TrafficShapingsList,
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
  },
  beforeMount () {
    if (!this.$store.state.formNetwork) { // Register store module only once
      this.$store.registerModule('formNetwork', FormStore)
    }
    if (!this.$store.state.formInline) { // Register store module only once
      this.$store.registerModule('formInline', FormStore)
    }
    if (!this.$store.state.formFencing) { // Register store module only once
      this.$store.registerModule('formFencing', FormStore)
    }
    if (!this.$store.state.formParking) { // Register store module only once
      this.$store.registerModule('formParking', FormStore)
    }
  }
}
</script>
