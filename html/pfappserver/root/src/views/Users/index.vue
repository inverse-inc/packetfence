<template>
  <b-row align-v="start">
    <section-sidebar v-model="sections" />
    <b-col cols="12" md="9" xl="10" class="py-3">
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
const setup = () => {
  const sections = computed(() => ([
    {
      name: i18n.t('Search'),
      path: '/users/search',
      saveSearchNamespace: 'users',
      standardSearches: [
        {
          name: i18n.t('Local Users'),
          conditionAdvanced: { op: 'and', values: [{ op: 'or', values: [{ field: 'account_type', op: 'equals', value: 'local' }] }] },
          sortBy: 'pid',
          sortDesc: false
        },
        {
          name: i18n.t('Remote Users'),
          conditionAdvanced: { op: 'and', values: [{ op: 'or', values: [{ field: 'account_type', op: 'equals', value: 'remote' }] }] },
          sortBy: 'pid',
          sortDesc: false
        }
      ]
    },
    {
      name: i18n.t('Create'),
      path: '/users/create',
      can: 'create users'
    },
    {
      name: i18n.t('Import'),
      path: '/users/import',
      can: 'create users'
    }
  ]))

  return {
    sections
  }
}

// @vue/component
export default {
  name: 'Users',
  components,
  setup
}
</script>
