<template>
  <b-card no-body>
    <pf-config-list
      ref="pfConfigList"
      :config="config"
    >
      <template v-slot:pageHeader>
        <b-card-header>
          <h4 class="mb-0">
            {{ $t('Network Behavior Policy') }}
          </h4>
        </b-card-header>
        
        <b-card-header v-if="!canUseNbaEndpoints">
          <template>
          <div class="alert alert-warning">{{ $t(`Your Fingerbank account currently doesn't have access to the network behavior analysis API endpoints. Get in touch with info@inverse.ca for a quote. Without these API endpoints, you will not be able to use the anomaly detection feature.`) }}</div>
          </template>
        </b-card-header>
      </template>
      <template v-slot:buttonAdd>
        <b-button variant="outline-primary" :to="{ name: 'newNetworkBehaviorPolicy' }">{{ $t('New Network Behavior Policy') }}</b-button>
      </template>
      <template v-slot:emptySearch="state">
        <pf-empty-table :isLoading="state.isLoading">{{ $t('No Network Behavior Policies found') }}</pf-empty-table>
      </template>
      <template v-slot:cell(buttons)="item">
        <span class="float-right text-nowrap">
          <pf-button-delete size="sm" v-if="!item.not_deletable" variant="outline-danger" class="mr-1" :disabled="isLoading" :confirm="$t('Delete Network Behavior Policy?')" @on-delete="remove(item)" reverse/>
          <b-button size="sm" variant="outline-primary" class="mr-1" @click.stop.prevent="clone(item)">{{ $t('Clone') }}</b-button>
        </span>
      </template>
    </pf-config-list>
  </b-card>
</template>

<script>
import pfButtonDelete from '@/components/pfButtonDelete'
import pfConfigList from '@/components/pfConfigList'
import pfEmptyTable from '@/components/pfEmptyTable'
import { config } from '../_config/networkBehaviorPolicy'

export default {
  name: 'network-behavior-policies-list',
  components: {
    pfButtonDelete,
    pfConfigList,
    pfEmptyTable
  },
  data () {
    return {
      config: config(this),
      canUseNbaEndpoints: false,
    }
  },
  computed: {
    isLoading () {
      return this.$store.getters['$_network_behavior_policies/isLoading']
    }
  },
  methods: {
    clone (item) {
      this.$router.push({ name: 'cloneNetworkBehaviorPolicy', params: { id: item.id } })
    },
    remove (item) {
      this.$store.dispatch('$_network_behavior_policies/deleteNetworkBehaviorPolicy', item.id).then(() => {
        const { $refs: { pfConfigList: { refreshList = () => {} } = {} } = {} } = this
        refreshList() // soft reload
      })
    },
    init () {
      this.$store.dispatch('$_fingerbank/getCanUseNbaEndpoints').then(info => {
        this.canUseNbaEndpoints = info["result"]
      })
    }
  },
  created () {
    this.init()
  }
}
</script>
