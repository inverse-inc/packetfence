<template>
  <b-card no-body>
    <pf-config-list
      :config="config"
    >
      <template slot="pageHeader">
        <b-card-header><h4 class="mb-0" v-t="'Roles'"></h4></b-card-header>
      </template>
      <template slot="buttonAdd">
        <b-button variant="outline-primary" :to="{ name: 'newRole' }">{{ $t('Add Role') }}</b-button>
      </template>
      <template slot="emptySearch" slot-scope="state">
        <pf-empty-table :isLoading="state.isLoading">{{ $t('No roles found') }}</pf-empty-table>
      </template>
      <template slot="buttons" slot-scope="item">
        <span class="float-right text-nowrap">
          <pf-button-delete size="sm" v-if="!item.not_deletable" variant="outline-danger" class="mr-1" :disabled="isLoading" :confirm="$t('Delete Role?')" @on-delete="remove(item)" reverse/>
          <b-button size="sm" variant="outline-primary" class="mr-1" @click.stop.prevent="clone(item)">{{ $t('Clone') }}</b-button>
          <b-button size="sm" variant="outline-primary" class="mr-1" :to="trafficShapingRoute(item.id)">{{ $t('Traffic Shaping') }}</b-button>
        </span>
      </template>
    </pf-config-list>
  </b-card>
</template>

<script>
import pfButtonDelete from '@/components/pfButtonDelete'
import pfConfigList from '@/components/pfConfigList'
import pfEmptyTable from '@/components/pfEmptyTable'
import {
  pfConfigurationRoleListConfig as config
} from '@/globals/configuration/pfConfigurationRoles'

export default {
  name: 'RolesList',
  components: {
    pfButtonDelete,
    pfConfigList,
    pfEmptyTable
  },
  data () {
    return {
      config: config(this),
      trafficShapingPolicies: []
    }
  },
  methods: {
    clone (item) {
      this.$router.push({ name: 'cloneRole', params: { id: item.id } })
    },
    remove (item) {
      this.$store.dispatch('$_roles/deleteRole', item.id).then(response => {
        this.$router.go() // reload
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
