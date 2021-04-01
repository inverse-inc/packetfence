<template>
  <b-card no-body>
    <pf-config-list
      ref="pfConfigList"
      :config="config"
    >
      <template v-slot:pageHeader>
        <b-card-header>
          <h4 v-t="'Inline Traffic Shaping Policy'" class="mb-0"></h4>
        </b-card-header>
      </template>
      <template v-slot:buttonAdd>
        <b-dropdown :text="$t('New Traffic Shaping Policy')" variant="outline-primary" :disabled="roles.length === 0">
          <b-dropdown-item v-for="role in roles" :key="role" :to="{ name: 'newTrafficShaping', params: { role: role } }">{{ role }}</b-dropdown-item>
        </b-dropdown>
      </template>
      <template v-slot:emptySearch="state">
          <pf-empty-table :is-loading="state.isLoading">{{ $t('No traffic shaping policies found') }}</pf-empty-table>
      </template>
      <template v-slot:cell(buttons)="item">
        <span class="float-right text-nowrap">
          <pf-button-delete size="sm" v-if="!item.not_deletable" variant="outline-danger" class="mr-1" :disabled="isLoading" :confirm="$t('Delete Traffic Shaping Policy?')" @on-delete="remove(item)" reverse/>
        </span>
      </template>
    </pf-config-list>
  </b-card>
</template>

<script>
import pfButtonDelete from '@/components/pfButtonDelete'
import pfConfigList from '@/components/pfConfigList'
import pfEmptyTable from '@/components/pfEmptyTable'
import { config } from '../_config/trafficShapingPolicy'

export default {
  name: 'traffic-shappings-list',
  components: {
    pfButtonDelete,
    pfConfigList,
    pfEmptyTable
  },
  data () {
    return {
      config: config(this), // ../_config/trafficShapingPolicy
      roles: []
    }
  },
  computed: {
    isLoading () {
      return this.$store.getters['$_roles/isLoading']
    }
  },
  methods: {
    init () {
      this.$store.dispatch('$_roles/all').then(roles => {
        const _roles = roles.map(role => role.id)
        this.$store.dispatch('$_traffic_shaping_policies/all').then(policies => {
          const _policies = policies.map(policy => policy.id)
          this.roles = _roles.filter(role => !(_policies.includes(role)))
        })
      })
    },
    remove (item) {
      this.$store.dispatch('$_traffic_shaping_policies/deleteTrafficShapingPolicy', item.id).then(() => {
        const { $refs: { pfConfigList: { refreshList = () => {} } = {} } = {} } = this
        refreshList() // soft reload
        this.init()
      })
    }
  },
  mounted () {
    this.init()
  }
}
</script>
