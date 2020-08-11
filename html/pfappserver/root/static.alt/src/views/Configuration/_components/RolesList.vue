<template>
  <b-card no-body>
    <pf-config-list
      :config="config"
    >
      <template v-slot:pageHeader>
        <b-card-header>
          <h4 class="mb-0">
            {{ $t('Roles') }}
            <pf-button-help class="ml-1" url="PacketFence_Installation_Guide.html#_introduction_to_role_based_access_control" />
          </h4>
        </b-card-header>
      </template>
      <template v-slot:buttonAdd>
        <b-button variant="outline-primary" :to="{ name: 'newRole' }">{{ $t('New Role') }}</b-button>
      </template>
      <template v-slot:emptySearch="state">
        <pf-empty-table :isLoading="state.isLoading">{{ $t('No roles found') }}</pf-empty-table>
      </template>
      <template v-slot:cell(buttons)="item">
        <span class="float-right text-nowrap text-right">
          <pf-button-delete size="sm" variant="outline-danger" class="mr-1" :disabled="isLoading" :confirm="$t('Delete Role?')" @on-delete="remove(item)" reverse/>
          <b-button size="sm" variant="outline-primary" class="mr-1" @click.stop.prevent="clone(item)">{{ $t('Clone') }}</b-button>
          <b-button v-if="isInline" size="sm" variant="outline-primary" class="mr-1" :to="trafficShapingRoute(item.id)">{{ $t('Traffic Shaping') }}</b-button>
        </span>
      </template>
    </pf-config-list>
  </b-card>
</template>

<script>
import pfButtonDelete from '@/components/pfButtonDelete'
import pfButtonHelp from '@/components/pfButtonHelp'
import pfConfigList from '@/components/pfConfigList'
import pfEmptyTable from '@/components/pfEmptyTable'
import { config } from '../_config/role'

export default {
  name: 'roles-list',
  components: {
    pfButtonDelete,
    pfButtonHelp,
    pfConfigList,
    pfEmptyTable
  },
  data () {
    return {
      config: config(this),
      trafficShapingPolicies: []
    }
  },
  computed: {
    isInline () {
      return this.$store.getters['system/isInline']
    }
  },
  methods: {
    clone (item) {
      this.$router.push({ name: 'cloneRole', params: { id: item.id } })
    },
    remove (item) {
      this.$store.dispatch('$_roles/deleteRole', item.id).then(() => {
        const { $refs: { pfConfigList: { refreshList = () => {} } = {} } = {} } = this
        refreshList() // soft reload
      })
    },
    trafficShapingRoute (id) {
      return (this.trafficShapingPolicies.includes(id))
        ? { name: 'traffic_shaping', params: { id } } // exists
        : { name: 'newTrafficShaping', params: { role: id } } // not exists
    }
  },
  created () {
    this.$store.dispatch('$_traffic_shaping_policies/all').then(response => {
      this.trafficShapingPolicies = response.map(policy => policy.id)
    })
  }
}
</script>
