<template>
  <b-card no-body>
    <b-card-header>
      <h5 class="mb-0">PacketFence</h5>
      <p class="mb-0"><mac>{{ version }}</mac></p>
    </b-card-header>
  </b-card>
</template>

<script>
export default {
  name: 'pf-network-graph-tooltip-packetfence',
  computed: {
    version () {
      return this.$store.getters['system/version']
    }
  }
}
</script>
