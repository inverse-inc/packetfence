<template>
  <b-card class="mt-3" no-body>
    <b-card-header>
      <div class="float-right"><toggle-button v-model="advancedMode">{{ $t('Advanced') }}</toggle-button></div>
      <h4 class="mb-0">{{ $t('Search Nodes') }}</h4>
    </b-card-header>
    <pf-search quick-with-fields="true" :fields="fields" :store="$store" :advanced-mode="advancedMode" @submit-search="onSearch"></pf-search>
    <div class="card-body">
      <b-table hover :items="items" :fields="columns"></b-table>
    </div>
  </b-card>
</template>

<script>
import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'
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
      // Fields must match the database schema
      fields: [ // keys match with b-form-select
        {
          value: 'mac',
          text: 'MAC Address',
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'bypass_role_id',
          text: 'Bypass Role',
          types: [conditionType.ROLE, conditionType.SUBSTRING]
        },
        {
          value: 'locationlog.connection_type',
          text: 'Connection Type',
          types: [conditionType.CONNECTION_TYPE]
        },
        {
          value: 'category_id',
          text: 'Node Role',
          types: [conditionType.ROLE, conditionType.SUBSTRING]
        },
        {
          value: 'voip',
          text: 'VoIP',
          types: [conditionType.BOOL]
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
  methods: {
    onSearch (condition) {
      let query = Object.assign({}, condition)
      if (!this.advancedMode) {
        query.values.splice(1)
      }
      this.$store.dispatch('$_nodes/search', query)
    }
  },
  created () {
    this.$store.dispatch('$_nodes/search', {})
    if (this.$store.state.config.roles.length === 0) {
      this.$store.dispatch('config/getRoles')
    }
  }
}
</script>

