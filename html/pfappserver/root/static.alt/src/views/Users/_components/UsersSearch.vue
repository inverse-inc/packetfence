<template>
  <b-card class="mt-3" no-body>
    <b-card-header>
      <div class="float-right"><toggle-button v-model="advancedMode">{{ $t('Advanced') }}</toggle-button></div>
      <h4 class="mb-0" v-t="'Search Users'"></h4>
    </b-card-header>
    <pf-search :quick-with-fields="false" quick-placeholder="Search by name or email" :fields="fields" :store="$store" :advanced-mode="advancedMode" @submit-search="onSearch"></pf-search>
    <div class="card-body">
      <b-table hover :items="items" :fields="columns"></b-table>
    </div>
  </b-card>
</template>

<script>
// import { mapGetters } from 'vuex'
import { pfSearchConditionType as attributeType } from '@/globals/pfSearch'
import pfSearch from '@/components/pfSearch'
import ToggleButton from '@/components/ToggleButton'

export default {
  name: 'UsersSearch',
  components: {
    'pf-search': pfSearch,
    'toggle-button': ToggleButton
  },
  // computed: {
  //   ...mapGetters(['session/username'])
  // },
  data () {
    return {
      advancedMode: false,
      // Fields must match the database schema
      fields: [ // keys match with b-form-select
        {
          value: 'pid',
          text: 'Username',
          types: [attributeType.SUBSTRING]
        },
        {
          value: 'email',
          text: 'Email',
          types: [attributeType.SUBSTRING]
        }
      ],
      columns: [
        {
          key: 'pid',
          label: this.$i18n.t('Username'),
          sortable: true
        },
        {
          key: 'firstname',
          label: this.$i18n.t('firstname'),
          sortable: true
        },
        {
          key: 'lastname',
          label: this.$i18n.t('lastname'),
          sortable: true
        },
        {
          key: 'email',
          label: this.$i18n.t('email'),
          sortable: true
        }
      ]
    }
  },
  computed: {
    items () {
      return this.$store.state.$_users.items
    }
  },
  methods: {
    onSearch (condition) {
      let query = Object.assign({}, condition)
      if (!this.advancedMode) {
        query.values.splice(1)
      }
      this.$store.dispatch('$_users/search', query)
    }
  },
  created () {
    this.$store.dispatch('$_users/search', {})
  }
}
</script>
