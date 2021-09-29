<template>
  <b-card no-body>
    <b-card-header>
      <h4 class="mb-0" v-t="'Main Configuration'"></h4>
    </b-card-header>
    <b-tabs ref="tabs" v-model="tabIndex" card lazy>
      <b-tab v-for="(tab, index) in tabs" :key="index"
        :title="$t(tab.title)" @click="tabIndex = index">
        <component :is="tab.component" />
      </b-tab>
    </b-tabs>
  </b-card>
</template>

<script>
import GeneralView from '../general/_components/TheView'
import AlertingView from '../alerting/_components/TheView'
import AdvancedView from '../advanced/_components/TheView'
import MaintenanceTasksSearch from '../maintenanceTasks/_components/TheSearch'
import ServicesView from '../services/_components/TheView'

const tabs = {
  general: {
    title: 'General Configuration', // i18n defer
    component: GeneralView
  },
  alerting: {
    title: 'Alerting', // i18n defer
    component: AlertingView
  },
  advanced: {
    title: 'Advanced', // i18n defer
    component: AdvancedView
  },
  maintenance_tasks: {
    title: 'Maintenance', // i18n defer
    component: MaintenanceTasksSearch
  },
  services: {
    title: 'Services', // i18n defer
    component: ServicesView
  }
}

const props = {
  tab: {
    type: String,
    default: Object.keys(tabs)[0]
  }
}

import { customRef, toRefs } from '@vue/composition-api'

const setup = (props, context) => {

  const {
    tab
  } = toRefs(props)

  const { root: { $router } = {} } = context

  const tabIndex = customRef((track, trigger) => ({
    get() {
      track()
      return Object.keys(tabs).indexOf(tab.value)
    },
    set(newValue) {
      $router.push({ name: Object.keys(tabs)[newValue] })
        .catch(e => { if (e.name !== "NavigationDuplicated") throw e })
      trigger()
    }
  }))

  return {
    tabs,
    tabIndex
  }
}

// @vue/component
export default {
  name: 'the-tabs-main',
  props,
  setup
}
</script>
