<template>
  <the-view v-if="shown" :id="current" />
  <the-form v-else />
</template>
<script>
/**
 * Historical logs in their header panel: the query, or the results of the
 * session shown. The panel keeps the session shown (logsPanel: current,
 * open), not the route: the page under the panel stays.
 */
import { computed, provide, ref } from '@vue/composition-api'
import store from '@/store'
import { loadClusterConfig } from '@/utils/cluster'
import StoreModule from '../_store/sessions'
import TheForm from './TheForm'
import TheView from './TheView'

const known = id => {
  const state = store.state.$_historical_logs
  return !!state && !!id && id in state
}

const setup = () => {
  if (!store.state.$_historical_logs)
    store.registerModule('$_historical_logs', StoreModule)
  loadClusterConfig()
  const last = store.state.$_historical_logs._lastSessionId
  const current = ref(known(last) ? last : null)
  const shown = computed(() => known(current.value))
  const open = id => {
    current.value = (known(id)) ? id : null
    if (current.value)
      store.commit('$_historical_logs/SET_LAST_SESSION', current.value)
  }
  provide('logsPanel', { current, open })
  return { current, shown }
}

// @vue/component
export default {
  name: 'the-historical-logs-panel',
  components: { TheForm, TheView },
  setup
}
</script>
