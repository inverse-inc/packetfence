<template>
  <b-card class="mt-3" header-tag="header" no-body>
    <div slot="header">
      <div class="float-right"><toggle-button v-model="advancedMode">{{ $t('Advanced') }}</toggle-button></div>
      <h4 v-t="'Search Users'"></h4>
    </div>
    <pf-search quick-without-fields="true" quick-placeholder="Search by name or email"
       :advanced-mode="advancedMode" :fields="fields"></pf-search>
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
      fields: [ // keys match with b-form-select
        {
          value: 'username',
          text: 'Username',
          type: attributeType.SUBSTRING
        },
        {
          value: 'email',
          text: 'Email',
          type: attributeType.SUBSTRING
        }
      ],
      columns: [
        {
          key: 'pid',
          label: this.$i18n.t('Username'),
          sortable: true
        },
        {
          key: this.$i18n.t('firstname'),
          sortable: true
        },
        {
          key: this.$i18n.t('lastname'),
          sortable: true
        },
        {
          key: this.$i18n.t('email'),
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
  created () {
    this.$store.dispatch('$_users/search', {})
  }
}
</script>
