<template>
  <b-card no-body>
    <b-card-header>
      <h4 v-t="'Live Logs'"></h4>
    </b-card-header>

    <live-log-tabs />

    <b-card-body>
    </b-card-body>
  </b-card>
</template>

<script>
import liveLogTabs from './LiveLogTabs'

export default {
  name: 'live-log-view',
  mixins: [
  ],
  components: {
    liveLogTabs
  },
  props: {
    storeName: {
      type: String,
      default: null
    },
    id: {
      type: String,
      default: null
    }
  },
  data () {
    return {
    }
  },
  methods: {
  }
}
</script>

