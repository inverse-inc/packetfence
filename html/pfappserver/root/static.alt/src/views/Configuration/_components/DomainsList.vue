<template>
  <pf-config-list
    :config="config"
  >
    <template slot="buttonAdd">
      <b-button variant="outline-primary" :to="{ name: 'newDomain' }">{{ $t('Add Domain') }}</b-button>
    </template>
    <template slot="emptySearch" slot-scope="state">
        <pf-empty-table :isLoading="state.isLoading">{{ $t('No domains found') }}</pf-empty-table>
    </template>
    <template slot="buttons" slot-scope="item">
      <span class="float-right text-nowrap">
        <pf-button-delete size="sm" v-if="!item.not_deletable" variant="outline-danger" class="mr-1" :disabled="isLoading" :confirm="$t('Delete Domain?')" @on-delete="remove(item)" reverse/>
        <b-button size="sm" variant="outline-primary" class="mr-1" @click.stop.prevent="clone(item)">{{ $t('Clone') }}</b-button>
        <b-button size="sm" variant="outline-warning" class="mr-1" @click.stop.prevent="rejoin(item)">{{ $t('Rejoin') }}</b-button>
      </span>
    </template>
    <template slot="ntlm_cache" slot-scope="data">
      <icon name="circle" :class="{ 'text-success': data.ntlm_cache === 'enabled', 'text-danger': data.ntlm_cache === 'disabled' }"
        v-b-tooltip.hover.left.d300 :title="$t(data.ntlm_cache)"></icon>
    </template>
  </pf-config-list>
</template>

<script>
import pfButtonDelete from '@/components/pfButtonDelete'
import pfConfigList from '@/components/pfConfigList'
import pfEmptyTable from '@/components/pfEmptyTable'
import {
  pfConfigurationDomainsListConfig as config
} from '@/globals/configuration/pfConfigurationDomains'

export default {
  name: 'DomainsList',
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
      config: config(this)
    }
  },
  methods: {
    clone (item) {
      this.$router.push({ name: 'cloneDomain', params: { id: item.id } })
    },
    rejoin (item) {
      // TODO
    },
    remove (item) {
      this.$store.dispatch(`${this.storeName}/deleteDomain`, item.id).then(response => {
        this.$router.go() // reload
      })
    }
  }
}
</script>
