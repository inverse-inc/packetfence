<template>
  <b-card class="mt-3" header-tag="header" no-body>
    <div slot="header">
      <div class="float-right"><toggle-button v-model="advancedMode">Advanced</toggle-button></div>
      <h4>Search Nodes</h4>
    </div>
    <pf-search quick-with-fields="true" :fields="fields" :advanced-mode="advancedMode"></pf-search>
    <div class="card-body">
      <b-table hover :items="items" :fields="columns"></b-table>
    </div>
  </b-card>
</template>

<script>
import { pfSearchConditionType as attributeType } from '@/globals/pfSearch'
import pfSearch from '@/components/pfSearch'
import ToggleButton from '@/components/ToggleButton'

export default {
  name: 'NodesSearch',
  components: {
    'pf-search': pfSearch,
    'toggle-button': ToggleButton
  },
  props: {
    namedSearch: String
  },
  data () {
    return {
      advancedMode: false,
      fields: [ // keys match with b-form-select
        {
          value: 'mac',
          text: 'MAC Address',
          type: attributeType.SUBSTRING
        },
        {
          value: 'bypass_role',
          text: 'Bypass Role',
          type: attributeType.SUBSTRING
        }
      ],
      columns: [
        {
          key: 'mac',
          label: this.$i18n.t('MAC Address'),
          sortable: true
        },
        {
          key: 'computername',
          label: this.$i18n.t('Computer Name'),
          sortable: true
        },
        {
          key: 'pid',
          label: this.$i18n.t('Owner'),
          sortable: true
        }
      ]
    }
  },
  computed: {
    items () {
      return this.$store.state.$_nodes.items
    }
  },
  created () {
    this.$store.dispatch('$_nodes/search', {})
  }
}
</script>

