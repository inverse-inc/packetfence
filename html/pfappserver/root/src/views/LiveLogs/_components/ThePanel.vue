<template>
  <the-view v-if="shown" :id="current" />
  <the-form v-else />
</template>
<script>
/**
 * Live logs in their header panel: the form, or the session shown. The panel
 * keeps the session shown (logsPanel: current, open), not the route: the page
 * under the panel stays.
 */
import { computed, provide, ref } from '@vue/composition-api'
import store from '@/store'
import { loadClusterConfig } from '@/utils/cluster'
import StoreModule from '../_store/sessions'
import TheForm from './TheForm'
import TheView from './TheView'

// a standalone session id, or a cluster group id
const known = id => {
  const state = store.state.$_live_logs
  return !!state && !!id && (id in state || (!!state._groups && id in state._groups))
}

const setup = () => {
  if (!store.state.$_live_logs)
    store.registerModule('$_live_logs', StoreModule)
  loadClusterConfig()
  const last = store.state.$_live_logs._lastSessionId
  const current = ref(known(last) ? last : null)
  const shown = computed(() => known(current.value))
  const open = id => {
    current.value = (known(id)) ? id : null
    if (current.value)
      store.commit('$_live_logs/SET_LAST_SESSION', current.value)
  }
  provide('logsPanel', { current, open })
  return { current, shown }
}

// @vue/component
export default {
  name: 'the-live-logs-panel',
  components: { TheForm, TheView },
  setup
}
</script>
