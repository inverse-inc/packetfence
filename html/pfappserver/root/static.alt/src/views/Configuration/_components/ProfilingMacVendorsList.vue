<template>
  <b-card no-body>
    <pf-config-list
      :config="config"
    >
      <template slot="pageHeader">
        <b-card-header><h4 class="mb-0" v-t="'MAC Vendors'"></h4></b-card-header>
      </template>
      <template slot="buttonAdd">
        <b-button variant="outline-primary" :to="{ name: 'newMacVendor' }">{{ $t('Add MAC Vendor') }}</b-button>
      </template>
      <template slot="emptySearch" slot-scope="state">
        <pf-empty-table :isLoading="state.isLoading">{{ $t('No MAC vendors found') }}</pf-empty-table>
      </template>
      <template slot="buttons" slot-scope="item">
        <span class="float-right text-nowrap">
          <pf-button-delete size="sm" v-if="!item.not_deletable" variant="outline-danger" class="mr-1" :disabled="isLoading" :confirm="$t('Delete MAC Vendor?')" @on-delete="remove(item)" reverse/>
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
import {
  pfConfigurationProfilingMacVendorsListConfig as config
} from '@/globals/configuration/pfConfigurationProfiling'

export default {
  name: 'ProfilingMacVendorsList',
  components: {
    pfButtonDelete,
    pfConfigList,
    pfEmptyTable
  },
  data () {
    return {
      macVendors: [], // all mac vendors
      config: config(this)
    }
  },
  methods: {
    clone (item) {
      this.$router.push({ name: 'cloneMacVendor', params: { id: item.id } })
    },
    remove (item) {
      this.$store.dispatch('$_profiling/deleteMacVendor', item.id).then(response => {
        this.$router.go() // reload
      })
    }
  },
  created () {
    this.$store.dispatch('$_profiling/macVendors').then(data => {
      this.macVendors = data
    })
  }
}
</script>
