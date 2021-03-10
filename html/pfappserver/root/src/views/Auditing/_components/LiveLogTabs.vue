<template>
  <b-tabs v-model="tabIndex" card>
    <b-tab v-for="(tab, index) in tabs" :key="tab.session_id" :title="tab.name" no-body
@zzzclick="go(index)"
    >
      <template v-slot:title>
        <span v-if="index > 0 && isLoading" class="float-right text-secondary ml-2">
          <icon name="circle-notch" scale="1.5" spin></icon>
        </span>
        <span v-else-if="index > 0" class="float-right text-secondary ml-2" @click.prevent.stop="destroy(tab.session_id)"
          v-b-tooltip.hover.top.d300 :title="$t('Close Session')"
        >
          <icon name="times" scale="1.5"></icon>
        </span>
        {{ $t(tab.name) }}
      </template>
      <!-- TABS ARE ONLY VISUAL, NOTHING HERE... -->
    </b-tab>
  </b-tabs>
</template>

<script>
import { computed, customRef } from '@vue/composition-api'
import i18n from '@/utils/locale'

const setup = (props, context) => {
  
  const { root: { $router, $store } = {} } = context
  
  const isLoading = computed(() => $store.getters['$_live_logs/isLoading'])
  const sessions = computed(() => $store.getters['$_live_logs/sessions'])
  const tabs = computed(() => ([
    { 
      name: i18n.t('Create Session'), 
      route: { name: 'live_logs' } 
    },
    ...sessions.value.map(session => {
      const { name, session_id } = session
      return {
        session_id,
        name,
        route: { name: 'live_log', params: { id: session_id } }
      }
    })
  ]))
  const tabIndex = customRef((track, trigger) => ({
    get() {
      track()
      const { params: { id } = {} } = $router.currentRoute
      if (id) {
        let sessionIndex = sessions.value.findIndex(s => {
          return s.session_id === id
        })
        if (sessionIndex > -1) {
          return sessionIndex + 1
        }
      }
      return 0
    },
    set(tabIndex) {
      $router.push(tabs.value[tabIndex].route)
      trigger()
    }
  }))  
  
  const destroy = (session_id) => {
    $store.dispatch('$_live_logs/destroySession', session_id).then(() => {
        const { params: { id } = {} } = $router.currentRoute
        if (session_id === id) { // tab is currently selected
          $router.push({ name: 'live_logs' })
        }
      })
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
  name: 'live-log-tabs',
  inheritAttrs: false,
  setup
}
</script>
