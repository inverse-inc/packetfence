<template>
  <pf-config-list
    :config="config"
  >
    <template v-slot:pageHeader>
      <b-card-header>
        <h4 v-t="'Inline Traffic Shaping Policy'"></h4>
      </b-card-header>
    </template>
    <template v-slot:buttonAdd>
      <b-dropdown :text="$t('New Traffic Shaping Policy')" variant="outline-primary" :disabled="roles.length === 0">
        <b-dropdown-item v-for="role in roles" :key="role" :to="{ name: 'newTrafficShaping', params: { role: role } }">{{ role }}</b-dropdown-item>
      </b-dropdown>
    </template>
    <template v-slot:emptySearch="state">
        <pf-empty-table :isLoading="state.isLoading">{{ $t('No traffic shaping policies found') }}</pf-empty-table>
    </template>
    <template v-slot:cell(buttons)="item">
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
  name: 'domains-list',
  components: {
    pfButtonDelete,
    pfConfigList,
    pfEmptyTable
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
      config: config(this),
      roles: []
    }
  },
  methods: {
    remove (item) {
      this.$store.dispatch(`${this.storeName}/deleteTrafficShapingPolicy`, item.id).then(response => {
        this.$router.go() // reload
      })
    }
  },
  created () {
    this.$store.dispatch('$_roles/all').then(roles => {
      const _roles = roles.map(role => role.id)
      this.$store.dispatch(`${this.storeName}/all`).then(policies => {
        const _policies = policies.map(policy => policy.id)
        this.roles = _roles.filter(role => !(_policies.includes(role)))
      })
    })
  }
}
</script>
