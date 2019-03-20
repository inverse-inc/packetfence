<template>
  <div>
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
    </pf-config-list>
  </div>
</template>

<script>
import pfConfigList from '@/components/pfConfigList'
import pfEmptyTable from '@/components/pfEmptyTable'
import {
  pfConfigurationRealmListConfig as config
} from '@/globals/configuration/pfConfigurationRealms'

export default {
  name: 'RealmsList',
  components: {
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
