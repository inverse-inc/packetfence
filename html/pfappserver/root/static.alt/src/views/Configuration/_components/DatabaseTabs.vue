<template>
  <b-card no-body>
    <b-card-header>
      <h4 class="mb-0" v-t="'Database Configuration'"></h4>
    </b-card-header>
    <b-tabs ref="tabs" v-model="tabIndex" card>
      <b-tab :title="$t('General Configuration')" @click="changeTab('database')">
        <database-view form-store-name="formDatabase" />
      </b-tab>
      <b-tab :title="$t('Advanced Configuration')" @click="changeTab('database_advanced')">
        <database-advanced-view form-store-name="formDatabaseAdvanced" />
      </b-tab>
    </b-tabs>
  </b-card>
</template>

<script>
import FormStore from '@/store/base/form'
import DatabaseView from './DatabaseView'
import DatabaseAdvancedView from './DatabaseAdvancedView'

export default {
  name: 'database-tabs',
  components: {
    DatabaseView,
    DatabaseAdvancedView
  },
  props: {
    tab: {
      type: String,
      default: 'database'
    }
  },
  computed: {
    tabIndex: {
      get () {
        return ['database', 'database_advanced'].indexOf(this.tab)
      },
      set () {
        // noop
      }
    }
  },
  methods: {
    changeTab (name) {
      this.$router.push({ name })
    }
  },
  beforeMount () {
    if (!this.$store.state.formDatabase) { // Register store module only once
      this.$store.registerModule('formDatabase', FormStore)
    }
    if (!this.$store.state.formDatabaseAdvanced) { // Register store module only once
      this.$store.registerModule('formDatabaseAdvanced', FormStore)
    }
  }
}
</script>
