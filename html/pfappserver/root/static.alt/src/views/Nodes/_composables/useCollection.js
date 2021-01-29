import { computed, toRefs } from '@vue/composition-api'

const useRouter = (props, context, form) => {
  const {
    id
  } = toRefs(props)
  const { root: { $router } = {} } = context
  return {
    goToCollection: () => $router.push({ name: 'nodes' }),
    goToItem: () => $router.push({ name: 'node', params: { mac: form.value.id || id.value } })
      .catch(e => { if (e.name !== "NavigationDuplicated") throw e }),
  }
}

const useStore = (props, context, form) => {
  const {
    id
  } = toRefs(props)
  const { root: { $store } = {} } = context
  return {
    isLoading: computed(() => $store.getters['$_nodes/isLoading']),
    reloadItem: () => $store.pdispatch('$_nodes/refreshNode', id.value),
    deleteItem: () => $store.dispatch('$_nodes/deleteNode', id.value),
    getItem: () => $store.dispatch('$_nodes/getNode', id.value),
    updateItem: () => $store.dispatch('$_nodes/updateNode', form.value),
    reevaluateAccess: () => $store.dispatch('$_nodes/reevaluateAccessNode', id.value),
    refreshFingerbank: () => $store.dispatch('$_nodes/refreshFingerbankNode', id.value),
    restartSwitchport: () => $store.dispatch('$_nodes/restartSwitchportNode', id.value),
    sortedSecurityEvents: () => $store.getters['config/sortedSecurityEvents'],
    applySecurityEvent: (triggerSecurityEvent) => $store.dispatch('$_nodes/applySecurityEventNode', { security_event_id: triggerSecurityEvent, mac: id.value })
  }
}

export {
  useRouter,
  useStore
}