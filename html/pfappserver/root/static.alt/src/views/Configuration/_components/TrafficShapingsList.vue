<template>
  <pf-config-list
    :config="config"
  >
    <template slot="pageHeader">
      <h4 v-t="'Inline Traffic Shaping Policy'"></h4>
    </template>
    <template slot="buttonAdd">
      <b-dropdown :text="$t('Add Traffic Shaping Policy')" variant="outline-primary" class="my-2" :disabled="roles.length === 0">
        <b-dropdown-item v-for="role in roles" :to="{ name: 'newTrafficShaping', params: { role: role } }">{{ role }}</b-dropdown-item>
      </b-dropdown>
    </template>
    <template slot="emptySearch" slot-scope="state">
        <pf-empty-table :isLoading="state.isLoading">{{ $t('No traffic shaping policies found') }}</pf-empty-table>
    </template>
    <template slot="buttons" slot-scope="item">
      <span class="float-right text-nowrap">
        <pf-button-delete size="sm" v-if="!item.not_deletable" variant="outline-danger" class="mr-1" :disabled="isLoading" :confirm="$t('Delete Traffic Shaping Policy?')" @on-delete="remove(item)" reverse/>
      </span>
    </template>
  </pf-config-list>
</template>

<script>
import pfButtonDelete from '@/components/pfButtonDelete'
import pfConfigList from '@/components/pfConfigList'
import pfEmptyTable from '@/components/pfEmptyTable'
import {
  pfConfigurationTrafficShapingPoliciesListConfig as config
} from '@/globals/configuration/pfConfigurationTrafficShapingPolicies'

export default {
  name: 'DomainsList',
  components: {
    pfButtonDelete,
    pfConfigList,
    pfEmptyTable
  },
  data () {
    return {
      config: config(this),
      roles: []
    }
  },
  methods: {
    remove (item) {
      this.$store.dispatch('$_traffic_shaping_policies/deleteTrafficShapingPolicy', item.id).then(response => {
        this.$router.go() // reload
      })
    }
  },
  created () {
    this.$store.dispatch('$_roles/all').then(roles => {
      const _roles = roles.map(role => role.id)
      this.$store.dispatch('$_traffic_shaping_policies/all').then(policies => {
        const _policies = policies.map(policy => policy.id)
        this.roles = _roles.filter(role => !(_policies.includes(role)))
      })
    })
  }
}
</script>
