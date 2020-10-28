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
        return i18n.t('Security Event {id}', { id: unref(id) })
      case unref(isClone):
        return i18n.t('Clone Security Event {id}', { id: unref(id) })
      default:
        return i18n.t('New Security Event')
    }
  })

  const isLoading = computed(() => $store.getters['$_security_events/isLoading'])

  const doInit = () => {
    if (!isNew.value) { // existing
      $store.dispatch('$_security_events/options').then(options => {
        const { meta: _meta = {} } = options
        meta.value = _meta
        $store.dispatch('$_security_events/getSecurityEvent', id.value).then(_form => {
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
      $store.dispatch('$_security_events/options').then(options => {
        const { meta: _meta = {} } = options
        form.value = { ...defaultsFromMeta(_meta), actions: [] }
        meta.value = _meta
      }).catch(() => {
        form.value = {}
        meta.value = {}
      })
    }
  }

  const doClone = () => $router.push({ name: 'cloneSecurityEvent' })

  const doClose = () => $router.push({ name: 'security_events' })

  const doRemove = () => $store.dispatch('$_security_events/deleteSecurityEvent', id.value).then(() => doClose())

  const doReset = doInit

  const doSave = () => {
    const closeAfter = actionKey.value
    switch (true) {
      case unref(isClone):
      case unref(isNew):
        $store.dispatch('$_security_events/createSecurityEvent', form.value).then(() => {
          if (closeAfter) // [CTRL] key pressed
            doClose()
          else
            $router.push({ name: 'security_event', params: { id: form.value.id } })
        })
        break
      default:
        $store.dispatch('$_security_events/updateSecurityEvent', form.value).then(() => {
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
