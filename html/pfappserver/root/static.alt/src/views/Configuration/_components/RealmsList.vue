<template>
  <pf-config-list
    ref="pfConfigList"
    :config="config"
  >
    <template v-slot:pageHeader>
      <h4 class="mb-0 p-4">
        {{ $t('Realms') }}
        <pf-button-help class="ml-1" url="PacketFence_Installation_Guide.html#_default_domain_configuration" />
      </h4>
    </template>
    <template v-slot:buttonAdd>
      <b-button variant="outline-primary" :to="{ name: 'newRealm' }">{{ $t('New Realm') }}</b-button>
        <pf-button-service class="ml-1" service="radiusd-acct" restart start stop></pf-button-service>
        <pf-button-service class="ml-1" service="radiusd-auth" restart start stop></pf-button-service>
    </template>
    <template v-slot:emptySearch="state">
      <pf-empty-table :isLoading="state.isLoading">{{ $t('No realms found') }}</pf-empty-table>
    </template>
    <template v-slot:cell(radius_auth)="{ radius_auth }">
      <span v-if="radius_auth.length === 0">&nbsp;<!-- hide empty --></span>
      <b-badge v-else v-for="(item, index) in radius_auth" :key="index" class="ml-2" variant="secondary">{{ item }}</b-badge>
    </template>
    <template v-slot:cell(radius_acct)="{ radius_acct }">
      <span v-if="radius_acct.length === 0">&nbsp;<!-- hide empty --></span>
      <b-badge v-else v-for="(item, index) in radius_acct" :key="index" class="ml-2" variant="secondary">{{ item }}</b-badge>
    </template>
    <template v-slot:cell(portal_strip_username)="{ portal_strip_username }">
      <icon name="circle" :class="{ 'text-success': portal_strip_username === 'enabled', 'text-danger': portal_strip_username === 'disabled' }"
        v-b-tooltip.hover.left.d300 :title="$t(portal_strip_username)"></icon>
    </template>
    <template v-slot:cell(admin_strip_username)="item">
      <icon name="circle" :class="{ 'text-success': item.admin_strip_username === 'enabled', 'text-danger': item.admin_strip_username === 'disabled' }"
        v-b-tooltip.hover.left.d300 :title="$t(item.admin_strip_username)"></icon>
    </template>
    <template v-slot:cell(radius_strip_username)="item">
      <icon name="circle" :class="{ 'text-success': item.radius_strip_username === 'enabled', 'text-danger': item.radius_strip_username === 'disabled' }"
        v-b-tooltip.hover.left.d300 :title="$t(item.radius_strip_username)"></icon>
    </template>
    <template v-slot:cell(buttons)="item">
      <span class="float-right text-nowrap">
        <pf-button-delete size="sm" v-if="!item.not_deletable" variant="outline-danger" class="mr-1" :disabled="isLoading" :confirm="$t('Delete Realm?')" @on-delete="remove(item)" reverse/>
        <b-button size="sm" variant="outline-primary" class="mr-1" @click.stop.prevent="clone(item)">{{ $t('Clone') }}</b-button>
      </span>
    </template>
  </pf-config-list>
</template>

<script>
import pfButtonDelete from '@/components/pfButtonDelete'
import pfButtonService from '@/components/pfButtonService'
import pfButtonHelp from '@/components/pfButtonHelp'
import pfConfigList from '@/components/pfConfigList'
import pfEmptyTable from '@/components/pfEmptyTable'
import { config } from '../_config/realm'

export default {
  name: 'realms-list',
  components: {
    pfButtonDelete,
    pfButtonService,
    pfButtonHelp,
    pfConfigList,
    pfEmptyTable
  },
  data () {
    return {
      config: config(this)
    }
  },
  methods: {
    clone (item) {
      this.$router.push({ name: 'cloneRealm', params: { id: item.id } })
    },
    remove (item) {
      this.$store.dispatch('$_realms/deleteRealm', item.id).then(() => {
        const { $refs: { pfConfigList: { refreshList = () => {} } = {} } = {} } = this
        refreshList() // soft reload
      })
    }
  }
}
</script>
