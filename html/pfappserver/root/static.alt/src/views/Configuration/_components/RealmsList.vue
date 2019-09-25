<template>
  <pf-config-list
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
    </template>
    <template v-slot:emptySearch="state">
      <pf-empty-table :isLoading="state.isLoading">{{ $t('No realms found') }}</pf-empty-table>
    </template>
    <template v-slot:cell(radius_auth)="data">
      <template v-if="data.radius_auth.length === 0">&nbsp;<!-- hide empty --></template>
      <b-badge v-else v-for="(item, index) in data.radius_auth" :key="index" class="ml-2" variant="secondary">{{ item }}</b-badge>
    </template>
    <template v-slot:cell(radius_acct)="data">
      <template v-if="data.radius_acct.length === 0">&nbsp;<!-- hide empty --></template>
      <b-badge v-else v-for="(item, index) in data.radius_acct" :key="index" class="ml-2" variant="secondary">{{ item }}</b-badge>
    </template>
    <template v-slot:cell(portal_strip_username)="data">
      <icon name="circle" :class="{ 'text-success': data.portal_strip_username === 'enabled', 'text-danger': data.portal_strip_username === 'disabled' }"
        v-b-tooltip.hover.left.d300 :title="$t(data.portal_strip_username)"></icon>
    </template>
    <template v-slot:cell(admin_strip_username)="data">
      <icon name="circle" :class="{ 'text-success': data.admin_strip_username === 'enabled', 'text-danger': data.admin_strip_username === 'disabled' }"
        v-b-tooltip.hover.left.d300 :title="$t(data.admin_strip_username)"></icon>
    </template>
    <template v-slot:cell(radius_strip_username)="data">
      <icon name="circle" :class="{ 'text-success': data.radius_strip_username === 'enabled', 'text-danger': data.radius_strip_username === 'disabled' }"
        v-b-tooltip.hover.left.d300 :title="$t(data.radius_strip_username)"></icon>
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
import pfButtonHelp from '@/components/pfButtonHelp'
import pfConfigList from '@/components/pfConfigList'
import pfEmptyTable from '@/components/pfEmptyTable'
import {
  pfConfigurationRealmListConfig as config
} from '@/globals/configuration/pfConfigurationRealms'

export default {
  name: 'realms-list',
  components: {
    pfButtonDelete,
    pfButtonHelp,
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
      config: config(this)
    }
  },
  methods: {
    clone (item) {
      this.$router.push({ name: 'cloneRealm', params: { id: item.id } })
    },
    remove (item) {
      this.$store.dispatch(`${this.storeName}/deleteRealm`, item.id).then(response => {
        this.$router.go() // reload
      })
    }
  }
}
</script>
