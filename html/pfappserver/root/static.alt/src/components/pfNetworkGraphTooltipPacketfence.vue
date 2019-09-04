<template>
  <b-card no-body>
    <b-card-header>
      <h5 class="mb-0"><mac>Packetfence</mac></h5>
    </b-card-header>
    <div class="card-body">
      <b-container fluid class="px-0">
        <b-row>
          <b-col cols="auto">
            <p class="py-0 col-form-label text-left text-nowrap" v-text="'Packetfence Version'"></p>
            <p class="mb-2" v-text="version"></p>
          </b-col>
        </b-row>
        <b-row>
          <b-col cols="auto">
            <p class="py-0 col-form-label text-left text-nowrap" v-text="'Packetfence Hostname'"></p>
            <p class="mb-2" v-text="hostname"></p>
          </b-col>
        </b-row>

      </b-container>
    </div>
  </b-card>
</template>

<script>
import pfFormRow from '@/components/pfFormRow'

export default {
  name: 'pf-network-graph-tooltip-packetfence',
  components: {
    pfFormRow
  },
  computed: {
    version () {
      return this.$store.getters['system/version']
    },
    hostname () {
      return this.$store.getters['system/hostname']
    }
  }
}
</script>
