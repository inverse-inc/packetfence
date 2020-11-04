import { computed, toRefs, unref, watch } from '@vue/composition-api'
import { useView as useBaseView, useViewProps as useBaseViewProps } from '@/composables/useView'
import i18n from '@/utils/locale'
import {
  defaultsFromMeta
} from '../../_config/'

const useViewProps = {
  ...useBaseViewProps,

  id: {
    type: String
  }
}

const useView = (props, context) => {

  const {
    id,
    isClone,
    isNew
  } = toRefs(props) // toRefs maintains reactivity w/ destructuring
  const { root: { $store, $router } = {} } = context

  const {
    rootRef,
    form,
    meta,
    customProps,
    actionKey,
    escapeKey,
    isDeletable,
    isValid
  } = useBaseView(props, context)

  const titleLabel = computed(() => {
    switch (true) {
      case !unref(isNew) && !unref(isClone):
        return i18n.t('Network Behavior Policy: <code>{id}</code>', { id: unref(id) })
      case unref(isClone):
        return i18n.t('Clone Network Behavior Policy: <code>{id}</code>', { id: unref(id) })
      default:
        return i18n.t('New Network Behavior Policy')
    }
  })

  const isLoading = computed(() => $store.getters['$_network_behavior_policies/isLoading'])

  const doInit = () => {
    if (!isNew.value) { // existing
      $store.dispatch('$_network_behavior_policies/options').then(options => {
        const { meta: _meta = {} } = options
        meta.value = _meta
        $store.dispatch('$_network_behavior_policies/getNetworkBehaviorPolicy', id.value).then(_form => {
          if (isClone.value) {
            _form.id = `${_form.id}-${i18n.t('copy')}`
            _form.not_deletable = false
          }
          form.value = _form
        }).catch(() => {
          form.value = {}
        })
      }).catch(() => {
        form.value = {}
        meta.value = {}
      })
    } else { // new
      $store.dispatch('$_network_behavior_policies/options').then(options => {
        const { meta: _meta = {} } = options
        form.value = { ...defaultsFromMeta(_meta), actions: [] }
        meta.value = _meta
      }).catch(() => {
        form.value = {}
        meta.value = {}
      })
    }
  }

  const doClone = () => $router.push({ name: 'cloneNetworkBehaviorPolicy' })

  const doClose = () => $router.push({ name: 'network_behavior_policies' })

  const doRemove = () => $store.dispatch('$_network_behavior_policies/deleteNetworkBehaviorPolicy', id.value).then(() => doClose())

  const doReset = doInit

  const doSave = () => {
    const closeAfter = actionKey.value
    switch (true) {
      case unref(isClone):
      case unref(isNew):
        $store.dispatch('$_network_behavior_policies/createNetworkBehaviorPolicy', form.value).then(() => {
          if (closeAfter) // [CTRL] key pressed
            doClose()
          else
            $router.push({ name: 'network_behavior_policy', params: { id: form.value.id } })
        })
        break
      default:
        $store.dispatch('$_network_behavior_policies/updateNetworkBehaviorPolicy', form.value).then(() => {
          if (closeAfter) // [CTRL] key pressed
            doClose()
        })
        break
    }
  }

  watch(escapeKey, () => doClose())

  watch(props, () => doInit(), { deep: true, immediate: true })

  return {
    rootRef,

    form,
    meta,
    customProps,
    titleLabel,

    actionKey,
    isLoading,
    isDeletable,
    isValid,

    doInit,
    doClone,
    doClose,
    doRemove,
    doReset,
    doSave
  }
}

export {
  useViewProps,
  useView
}
