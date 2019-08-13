<template>
  <b-card no-body class="mt-3">
    <b-card-header>
      <h4 class="d-inline mb-0" v-t="'Network'"></h4>
    </b-card-header>
    <div class="card-body">

      <pf-network-graph ref="networkGraph"
        :storeName="storeName"
        :dimensions="dimensions"
        :bounds="bounds"
        :coords="coords"
        :links="links"
        :nodes="nodes"
        :is-loading="isLoading"
        :mini-map-height="150"
        :tooltip-distance="10"
        :min-zoom="0"
        :max-zoom="4"
      />

    </div>
  </b-card>
</template>

<script>
import pfNetworkGraph from '@/components/pfNetworkGraph'

export default {
  name: 'network',
  components: {
    pfNetworkGraph
  },
  props: {
    storeName: { // from router
      type: String,
      default: null,
      required: true
    }
  },
  data () {
    return {
      dimensions: {
        height: Math.max(document.documentElement.clientHeight, window.innerHeight || 0) - 40,
        width: 0
      }
    }
  },
  computed: {
    isLoading () {
      return this.$store.state[this.storeName].isLoading
    },
    bounds () {
      return this.$store.getters[`${this.storeName}/bounds`]
    },
    coords () {
      return this.$store.getters[`${this.storeName}/coords`]
    },
    links () {
      return this.$store.getters[`${this.storeName}/links`]
    },
    nodes () {
      return this.$store.getters[`${this.storeName}/nodes`]
    },
    windowSize () {
      return this.$store.getters['events/windowSize']
    }
  },
  methods: {
    setDimensions () {
      // get width of svg container
      const { $refs: { networkGraph: { $el: { offsetWidth: width = 0 } = {} } = {} } = {} } = this
      this.$set(this.dimensions, 'width', width)
      this.$store.dispatch(`${this.storeName}/setDimensions`, this.dimensions)
    }
  },
  mounted () {
    this.setDimensions()
    this.$store.dispatch(`${this.storeName}/startPolling`)
  },
  beforeDestroy () {
    this.$store.dispatch(`${this.storeName}/stopPolling`)
  },
  watch: {
    windowSize: {
      handler: function (a, b) {
        if (a.clientWidth !== b.clientWidth || a.clientHeight !== b.clientHeight) {
          this.setDimensions()
        }
      },
      deep: true
    }
  }
}
</script>
