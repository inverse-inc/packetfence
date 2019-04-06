<template>
  <b-card no-body>
    <b-card-header>
      <h4 class="mb-0" v-t="'Main Configuration'"></h4>
    </b-card-header>
    <b-tabs ref="tabs" v-model="tabIndex" card>
      <b-tab :title="$t('General Configuration')" @click="changeTab('general')">
        <general-view />
      </b-tab>
      <b-tab :title="$t('Alerting')" @click="changeTab('alerting')">
        <alerting-view />
      </b-tab>
      <b-tab :title="$t('Advanced')" @click="changeTab('advanced')">
        <advanced-view />
      </b-tab>
      <b-tab :title="$t('Maintenance')" @click="changeTab('maintenance_tasks')">
        <maintenance-tasks-list storeName="$_maintenance_tasks" />
      </b-tab>
      <b-tab :title="$t('Services')" @click="changeTab('services')">
        <services-view />
      </b-tab>
    </b-tabs>
  </b-card>
</template>

<script>
import GeneralView from './GeneralView'
import AlertingView from './AlertingView'
import AdvancedView from './AdvancedView'
import MaintenanceTasksList from './MaintenanceTasksList'
import ServicesView from './ServicesView'

export default {
  name: 'MainTabs',
  components: {
    GeneralView,
    AlertingView,
    AdvancedView,
    MaintenanceTasksList,
    ServicesView
  },
  props: {
    tab: {
      type: String,
      default: 'general'
    }
  },
  computed: {
    tabIndex () {
      return ['general', 'alerting', 'advanced', 'maintenance_tasks', 'services'].indexOf(this.tab)
    }
  },
  methods: {
    changeTab (name) {
      this.$router.push({ name })
    }
  }
}
</script>
