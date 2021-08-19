<template>
  <b-row>
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
      name: i18n.t('Settings'),
      path: '/preferences/settings'
    },
    {
      name: i18n.t('Permissions'),
      path: '/preferences/permissions'
    }
  ]))

  return {
    sections
  }
}

// @vue/component
export default {
  name: 'Preferences',
  components,
  setup
}
</script>
