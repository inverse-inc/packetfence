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
  </pf-config-list>
</template>

<script>
import pfConfigList from '@/components/pfConfigList'
import pfEmptyTable from '@/components/pfEmptyTable'
import {
  pfConfigurationDomainsListConfig as config
} from '@/globals/configuration/pfConfigurationDomains'

export default {
  name: 'DomainsList',
  components: {
    pfConfigList,
    pfEmptyTable
  },
  data () {
    return {
      config: config(this)
    }
  }
}
</script>
