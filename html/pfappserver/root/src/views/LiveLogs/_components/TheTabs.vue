<template>
  <b-tabs v-if="tabs.length > 0" v-model="tabIndex" card>
    <b-tab v-for="tab in tabs" :key="tab.id" :title="tab.name" no-body>
      <template v-slot:title>
        <span v-if="isLoading" class="float-right text-secondary ml-2">
          <icon name="circle-notch" scale="1.5" spin />
        </span>
        <span v-else class="float-right text-secondary ml-2" @click.prevent.stop="destroy(tab.id)"
          v-b-tooltip.hover.top.d300 :title="$t('Close Session')"
        >
          <icon name="times" scale="1.5" />
        </span>
        {{ $t(tab.name) }}
        <span v-if="tab.peerCount > 1" class="text-secondary">({{ $t('{n} nodes', { n: tab.peerCount }) }})</span>
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
  // One tab per cluster group (merged view) or standalone session, never per peer.
  const tabs = computed(() => (
    $store.getters['$_live_logs/tabs'].map(tab => ({
      ...tab,
      route: { name: 'live_log', params: { id: tab.id } }
    }))
  ))
  const tabIndex = customRef((track, trigger) => ({
    get() {
      track()
      const { params: { id } = {} } = $router.currentRoute
      if (id) {
        const index = tabs.value.findIndex(tab => tab.id === id)
        if (index > -1) return index
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

  const destroy = (id) => {
    const { params: { id: routeId } = {} } = $router.currentRoute
    if (id === routeId) {
      $router.push({ name: 'live_logs' })
    }
    $store.dispatch('$_live_logs/destroySession', id)
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
