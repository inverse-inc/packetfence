<template>
  <b-card no-body class="mt-3">
    <b-card-header>
      <h4 class="d-inline mb-0" v-t="'Network'"></h4>
    </b-card-header>
    <div class="card-body">
      <pf-network-graph ref="networkGraph"
        :dimensions="dimensions"
        :nodes="nodes"
        :links="links"
        :options="options"
        :is-loading="isLoading"
      />
    </div>
  </b-card>
</template>

<script>
import pfNetworkGraph from '@/components/pfNetworkGraph'
import apiCall from '@/utils/api'

const api = {
  networkGraph: body => {
    return apiCall.post('nodes/network_graph', body).then(response => {
      return response.data
    })
  }
}

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
      },
      nodes: [],
      links: [],
      options: {
        layout: 'radial',
        tooltipDistance: 50,
        miniMapHeight: undefined,
        miniMapWidth: 200,
        miniMapPosition: 'bottom-left',
        minZoom: 0,
        maxZoom: 4
      },
      pollingIntervalMs: 60000,
      pollingInterval: false,
      query: {
        cursor: 0,
        limit: '100',
        fields: ['mac', 'tenant_id', 'status', 'detect_date', 'regdate', 'unregdate', 'computername', 'pid', 'device_manufacturer', 'category_id', 'last_seen'],
        sort: ['last_seen DESC'],
        query: {
          op: 'and',
          values: [{
              op: 'or',
              values: [{
                  field: 'last_seen',
                  op: 'greater_than_equals',
                  value: '2000-01-01 00:00:00'
              }]
          }]
        }
      }
    }
  },
  computed: {
    isLoading () {
      return this.$store.state[this.storeName].isLoading
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
    },
    startPolling () {
      this.stopPolling()
      this.pollingInterval = setInterval(() => {
        this.doPoll()
      }, this.pollingIntervalMs)
      this.doPoll()
    },
    stopPolling () {
      if (this.pollingInterval) {
        clearInterval(this.pollingInterval)
        this.pollingInterval = false
      }
    },
    doPoll () {
      api.networkGraph(this.query).then(response => {
        let { network_graph: { nodes, links } = {} } = response
        /*
        // improve layout by sorting nodes by source id
        nodes = nodes.sort((a, b) => {
          const { source: aSourceId = null } = links.find(l => l.target === a.id) || {}
          const { source: bSourceId = null } = links.find(l => l.target === b.id) || {}
          switch (true) {
            case aSourceId.localeCompare(bSourceId) === -1:
              return -1
            case aSourceId.localeCompare(bSourceId) === 1:
              return 1
            case a.id.localeCompare(b.id) === -1:
              return -1
            case a.id.localeCompare(b.id) === 1:
              return 1
            default:
              return 0
          }
        })
        links = links.sort((a, b) => {
          return a.source.localeCompare(b.source)
        })
        */
        this.$set(this, 'nodes', nodes)
        this.$set(this, 'links', links)
      })
    }
  },
  mounted () {
    this.setDimensions()
    this.startPolling()
  },
  beforeDestroy () {
    this.stopPolling()
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
