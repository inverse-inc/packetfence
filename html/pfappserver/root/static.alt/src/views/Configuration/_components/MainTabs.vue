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
      <b-tab :title="$t('Maintenance')" @click="changeTab('maintenance_tasks')" no-body>
        <maintenance-tasks-list form-store-name="formMaintenanceTasks" />
      </b-tab>
      <b-tab :title="$t('Services')" @click="changeTab('services')">
        <services-view />
      </b-tab>
    </b-tabs>
  </b-card>
</template>

<script>
import GeneralView from '../general/_components/TheView'
import AlertingView from '../alerting/_components/TheView'
import AdvancedView from '../advanced/_components/TheView'
import MaintenanceTasksList from './MaintenanceTasksList'
import ServicesView from '../services/_components/TheView'

export default {
  name: 'main-tabs',
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
    tabIndex: {
      get () {
        return ['general', 'alerting', 'advanced', 'maintenance_tasks', 'services'].indexOf(this.tab)
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
