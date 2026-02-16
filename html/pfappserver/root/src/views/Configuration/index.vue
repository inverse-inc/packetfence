<template>
  <b-row align-v="start">
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

import { useSections } from './_composables/useSections'
const setup = () => {
  const { sections } = useSections()

  return {
    sections
  }
}

// @vue/component
export default {
  name: 'Configuration',
  components,
  setup
}
</script>
