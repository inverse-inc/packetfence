<template>
  <b-row>
    <section-sidebar v-model="sections" />
    <b-col cols="12" md="9" xl="10" class="pt-3 pb-3">
      <transition name="slide-bottom">
        <router-view />
      </transition>
    </b-col>
  </b-row>
</template>

<script>
import SectionSidebar from '@/components/SectionSidebar'
const components = {
  SectionSidebar
}

import { computed } from '@vue/composition-api'
import i18n from '@/utils/locale'
const setup = (props, context) => {

  const { root: { $store } = {} } = context

  const cluster = computed(() => $store.state.$_status.cluster || [])
  const sections = computed(() => ([
    {
      name: i18n.t('Dashboard'),
      path: '/status/dashboard',
      can: 'master tenant'
    },
    {
      name: i18n.t('Network View'),
      path: '/status/network',
      saveSearchNamespace: 'network',
      can: 'read nodes'
    },
    {
      name: i18n.t('Services'),
      path: '/status/services',
      can: 'read services'
    },
    {
      name: i18n.t('Local Queue'),
      path: '/status/queue',
      can: 'master tenant'
    },
    ...((cluster.value.length > 1)
      ? [{
        name: i18n.t('Cluster'),
        items: [
          {
            name: i18n.t('Services'),
            path: '/status/cluster/services'
          }
        ]
      }]
      : []
    )
  ]))

  return {
    sections
  }
}

// @vue/component
export default {
  name: 'Status',
  components,
  setup
}
</script>
