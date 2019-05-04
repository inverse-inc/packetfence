<template>
    <b-card no-body class="mt-3">
      <b-card-header>
        <h4 class="mb-0" v-t="'Cluster Services'"></h4>
      </b-card-header>
      <div class="card-body">
        <b-table
          :fields="fields"
          :items="items"
          :sort-by="sortBy"
          :sort-desc="sortDesc"
          :hover="services.length > 0"
          show-empty
          responsive
          fixed
          striped
        >
          <template slot="empty">
            <pf-empty-table :isLoading="isLoading" text="">{{ $t('No Services found') }}</pf-empty-table>
          </template>
          <template v-for="server in servers" :slot="server" slot-scope="{ item: { [server]: status } }">
            <div class="container-status small" :key="server">
              <b-row class="row-nowrap">
                  <b-col>{{ $t('Alive') }}</b-col>
                  <b-col cols="auto">
                    <b-badge v-if="status.alive && status.pid" pill variant="success">{{ status.pid }}</b-badge>
                    <icon v-else class="text-danger" name="circle"></icon>
                  </b-col>
              </b-row>
              <b-row class="row-nowrap">
                  <b-col>{{ $t('Enabled') }}</b-col>
                  <b-col cols="auto"><icon :class="(status.enabled) ? 'text-success' : 'text-danger'" name="circle"></icon></b-col>
              </b-row>
              <b-row class="row-nowrap">
                  <b-col>{{ $t('Managed') }}</b-col>
                  <b-col cols="auto"><icon :class="(status.managed) ? 'text-success' : 'text-danger'" name="circle"></icon></b-col>
              </b-row>
            </div>
          </template>
        </b-table>
      </div>
    </b-card>
</template>

<script>
import pfEmptyTable from '@/components/pfEmptyTable'
import pfFormRangeToggle from '@/components/pfFormRangeToggle'

export default {
  name: 'ClusterServices',
  components: {
    pfEmptyTable,
    pfFormRangeToggle
  },
  props: {
    storeName: { // from router
      type: String,
      default: null,
      required: true
    }
  },
  computed: {
    isLoading () {
      return this.$store.getters[`${this.storeName}/isClusterServicesLoading`]
    },
    servers () {
      return this.$store.state[this.storeName].clusterServices.map(server => server.host)
    },
    services () {
      const allServices = this.$store.state[this.storeName].clusterServices.map(server => {
        return server.services.map(service => service.name)
      })
      return this.uniqueServices(...allServices)
    },
    fields () {
      return [
        {
          key: 'service',
          label: this.$i18n.t('Service'),
          sortable: true
        }
      ].concat(this.servers.map(server => {
        return { key: server, label: server, sortable: false }
      }))
    },
    items () {
      return this.services.map(service => {
        let statuses = { service }
        this.servers.forEach(server => {
          const { services = {} } = this.$store.state[this.storeName].clusterServices.find(o => o.host === server)
          const { status } = services.find(o => o.name === service)
          statuses[server] = status
        })
        return statuses
      })
    }
  },
  methods: {
    uniqueServices: (...services) => [ ...new Set([].concat(...services)) ]
  },
  data () {
    return {
      sortBy: 'service',
      sortDesc: false
    }
  },
  created () {
    this.$store.dispatch(`${this.storeName}/getClusterServices`)
  }
}
</script>

<style lang="scss">
.container-status {
    max-width: 200px;
}
</style>
