<template>
  <b-card no-body>
    <b-card-header>
      <h4 class="mb-0" v-t="'Database Configuration'"></h4>
    </b-card-header>
    <b-tabs ref="tabs" v-model="tabIndex" card>
      <b-tab :title="$t('General Configuration')" @click="changeTab('database_general')">
        <database-general-view />
      </b-tab>
      <b-tab :title="$t('Advanced Configuration')" @click="changeTab('database_advanced')">
        <database-advanced-view />
      </b-tab>
    </b-tabs>
  </b-card>
</template>

<script>
import DatabaseGeneralView from '../database/general/_components/TheView'
import DatabaseAdvancedView from '../database/advanced/_components/TheView'

export default {
  name: 'database-tabs',
  components: {
    DatabaseGeneralView,
    DatabaseAdvancedView
  },
  props: {
    tab: {
      type: String,
      default: 'database_general'
    }
  },
  computed: {
    tabIndex: {
      get () {
        return ['database_general', 'database_advanced'].indexOf(this.tab)
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
  }
}
</script>
