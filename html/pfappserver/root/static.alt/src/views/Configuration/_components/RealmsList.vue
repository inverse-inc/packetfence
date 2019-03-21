<template>
  <pf-config-list
    :config="config"
  >
    <template slot="buttonAdd">
      <b-button variant="outline-primary" :to="{ name: 'newRealm' }">{{ $t('Add Realm') }}</b-button>
    </template>
    <template slot="emptySearch" slot-scope="state">
      <pf-empty-table :isLoading="state.isLoading">{{ $t('No realms found') }}</pf-empty-table>
    </template>
    <template slot="buttons" slot-scope="item">
      <span class="float-right text-nowrap">
        <pf-button-delete size="sm" v-if="!item.not_deletable" variant="outline-danger" class="mr-1" :disabled="isLoading" :confirm="$t('Delete Realm?')" @on-delete="remove(item)" reverse/>
        <b-button size="sm" variant="outline-primary" class="mr-1" @click.stop.prevent="clone(item)">{{ $t('Clone') }}</b-button>
      </span>
    </template>
    <template slot="portal_strip_username" slot-scope="data">
      <icon name="circle" :class="{ 'text-success': data.portal_strip_username === 'enabled', 'text-danger': data.portal_strip_username === 'disabled' }"
        v-b-tooltip.hover.left.d300 :title="$t(data.portal_strip_username)"></icon>
    </template>
    <template slot="admin_strip_username" slot-scope="data">
      <icon name="circle" :class="{ 'text-success': data.admin_strip_username === 'enabled', 'text-danger': data.admin_strip_username === 'disabled' }"
        v-b-tooltip.hover.left.d300 :title="$t(data.admin_strip_username)"></icon>
    </template>
    <template slot="radius_strip_username" slot-scope="data">
      <icon name="circle" :class="{ 'text-success': data.radius_strip_username === 'enabled', 'text-danger': data.radius_strip_username === 'disabled' }"
        v-b-tooltip.hover.left.d300 :title="$t(data.radius_strip_username)"></icon>
    </template>
  </pf-config-list>
</template>

<script>
import pfButtonDelete from '@/components/pfButtonDelete'
import pfConfigList from '@/components/pfConfigList'
import pfEmptyTable from '@/components/pfEmptyTable'
import {
  pfConfigurationRealmListConfig as config
} from '@/globals/configuration/pfConfigurationRealms'

export default {
  name: 'RealmsList',
  components: {
    pfButtonDelete,
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
      this.$store.dispatch('$_realms/deleteRealm', item.id).then(response => {
        this.$router.go() // reload
      })
    }
  }
}
</script>
