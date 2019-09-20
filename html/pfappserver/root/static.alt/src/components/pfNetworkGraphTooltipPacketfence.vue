<template>
  <b-card no-body>
    <b-card-header>
      <h5 class="mb-0">Packetfence</h5>
      <p class="mb-0"><mac>{{ version }}</mac></p>
    </b-card-header>
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
    }
  }
}
</script>
