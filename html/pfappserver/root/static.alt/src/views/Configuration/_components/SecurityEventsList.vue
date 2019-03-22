<template>
  <b-card no-body>
    <pf-config-list
      :config="config"
    >
      <template slot="pageHeader">
        <b-card-header><h4 class="mb-0" v-t="'Security Events'"></h4></b-card-header>
      </template>
      <template slot="buttonAdd">
        <b-button variant="outline-primary" :to="{ name: 'newSecurityEvent' }">{{ $t('Add Security Event') }}</b-button>
      </template>
      <template slot="emptySearch">
        <pf-empty-table :isLoading="isLoading">{{ $t('No security events found') }}</pf-empty-table>
      </template>
    </pf-config-list>
  </b-card>
</template>

<script>
import pfConfigList from '@/components/pfConfigList'
import pfEmptyTable from '@/components/pfEmptyTable'
import {
  pfConfigurationSecurityEventListConfig as config
} from '@/globals/configuration/pfConfigurationSecurityEvents'

export default {
  name: 'SecurityEventsList',
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
