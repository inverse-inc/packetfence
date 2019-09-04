<template>
  <b-card no-body>
    <b-card-header>
      <h5 class="mb-0"><mac>{{ id }}</mac></h5>
    </b-card-header>
    <div class="card-body" v-if="hasLocationLogProperties">
      <b-container fluid class="px-0">
        <b-row v-if="properties.locationlog.switch">
          <b-col cols="auto">
            <p class="py-0 col-form-label text-left text-nowrap" v-text="'Switch IP'"></p>
            <p class="mb-2" v-text="properties.locationlog.switch"></p>
          </b-col>
        </b-row>
        <b-row v-if="properties.locationlog.port">
          <b-col cols="auto">
            <p class="py-0 col-form-label text-left text-nowrap" v-text="'Switch Port'"></p>
            <p class="mb-2" v-text="properties.locationlog.port"></p>
          </b-col>
        </b-row>
        <b-row v-if="properties.locationlog.switch_mac">
          <b-col cols="auto">
            <p class="py-0 col-form-label text-left text-nowrap" v-text="'Switch MAC'"></p>
            <p class="mb-2" v-text="properties.locationlog.switch_mac"></p>
          </b-col>
        </b-row>
        <b-row v-if="properties.locationlog.connection_type">
          <b-col cols="auto">
            <p class="py-0 col-form-label text-left text-nowrap" v-text="'Connection Type'"></p>
            <p class="mb-2 text-nowrap" v-text="properties.locationlog.connection_type"></p>
          </b-col>
        </b-row>
        <b-row v-if="properties.locationlog.ssid">
          <b-col cols="auto">
            <p class="py-0 col-form-label text-left text-nowrap" v-text="'SSID'"></p>
            <p class="mb-2 text-nowrap" v-text="properties.locationlog.ssid"></p>
          </b-col>
        </b-row>
        <b-row v-if="properties.locationlog.role">
          <b-col cols="auto">
            <p class="py-0 col-form-label text-left text-nowrap" v-text="'Role'"></p>
            <p class="mb-2 text-nowrap" v-text="properties.locationlog.role"></p>
          </b-col>
        </b-row>
        <b-row v-if="properties.locationlog.vlan">
          <b-col cols="auto">
            <p class="py-0 col-form-label text-left text-nowrap" v-text="'VLAN ID'"></p>
            <p class="mb-2" v-text="properties.locationlog.vlan"></p>
          </b-col>
        </b-row>
        <b-row v-if="properties.locationlog.realm">
          <b-col cols="auto">
            <p class="py-0 col-form-label text-left text-nowrap" v-text="'Realm'"></p>
            <p class="mb-2" v-text="properties.locationlog.realm"></p>
          </b-col>
        </b-row>
      </b-container>
    </div>
  </b-card>
</template>

<script>
import pfFormRow from '@/components/pfFormRow'

export default {
  name: 'pf-network-graph-tooltip-switch',
  components: {
    pfFormRow
  },
  props: {
    id: {
      type: String
    },
    properties: {
      type: Object,
      default: () => { return {} }
    }
  },
  computed: {
    hasLocationLogProperties () {
      return 'locationlog' in this.properties && Object.keys(this.properties.locationlog).filter(key => this.properties.locationlog[key]).length > 0
    }
  }
}
</script>
