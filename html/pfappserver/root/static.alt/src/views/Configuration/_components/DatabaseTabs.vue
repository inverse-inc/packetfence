<template>
  <b-card no-body>
    <b-card-header>
      <h4 class="mb-0" v-t="'Database Configuration'"></h4>
    </b-card-header>
    <b-tabs ref="tabs" v-model="tabIndex" card>
      <b-tab :title="$t('General Configuration')" @click="changeTab('database')">
        <database-view />
      </b-tab>
      <b-tab :title="$t('Advanced Configuration')" @click="changeTab('database_advanced')">
        <database-advanced-view />
      </b-tab>
    </b-tabs>
  </b-card>
</template>

<script>
import DatabaseView from './DatabaseView'
import DatabaseAdvancedView from './DatabaseAdvancedView'

export default {
  name: 'DatabaseTabs',
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
    tabIndex () {
      return ['database', 'database_advanced'].indexOf(this.tab)
    }
  },
  methods: {
    changeTab (name) {
      this.$router.push({ name })
    }
  }
}
</script>
