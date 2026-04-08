<template>
  <b-tabs v-if="tabs.length > 0" v-model="tabIndex" card>
    <b-tab v-for="tab in tabs" :key="tab.session_id" :title="tab.name" no-body>
      <template v-slot:title>
        <span v-if="isLoading" class="float-right text-secondary ml-2">
          <icon name="circle-notch" scale="1.5" spin />
        </span>
        <span v-else class="float-right text-secondary ml-2" @click.prevent.stop="destroy(tab.session_id)"
          v-b-tooltip.hover.top.d300 :title="$t('Close Session')"
        >
          <icon name="times" scale="1.5" />
        </span>
        {{ $t(tab.name) }}
      </template>
      <!-- TABS ARE ONLY VISUAL, NOTHING HERE... -->
    </b-tab>
  </b-tabs>
</template>

<script>
import { computed, customRef } from '@vue/composition-api'

const setup = (props, context) => {

  const { root: { $router, $store } = {} } = context

  const isLoading = computed(() => $store.getters['$_live_logs/isLoading'])
  const sessions = computed(() => $store.getters['$_live_logs/sessions'])
  const tabs = computed(() => (
    sessions.value.map(session => {
      const { name, session_id } = session
      return {
        session_id,
        name,
        route: { name: 'live_log', params: { id: session_id } }
      }
    })
  ))
  const tabIndex = customRef((track, trigger) => ({
    get() {
      track()
      const { params: { id } = {} } = $router.currentRoute
      if (id) {
        const sessionIndex = sessions.value.findIndex(s => s.session_id === id)
        if (sessionIndex > -1) return sessionIndex
      }
      return -1
    },
    set(tabIndex) {
      if (tabIndex >= 0 && tabs.value[tabIndex]) {
        $router.push(tabs.value[tabIndex].route)
          .then(() => trigger())
          .catch(() => {})
      }
    }
  }))

  const destroy = (session_id) => {
    const { params: { id } = {} } = $router.currentRoute
    if (session_id === id) {
      $router.push({ name: 'live_logs' })
    }
    $store.dispatch('$_live_logs/destroySession', session_id)
  }

  return {
    isLoading,
    tabs,
    tabIndex,
    destroy
  }
}

// @vue/component
export default {
  name: 'the-tabs',
  inheritAttrs: false,
  setup
}
</script>
