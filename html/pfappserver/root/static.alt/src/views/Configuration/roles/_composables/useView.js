import { computed, ref, toRefs, unref, watch } from '@vue/composition-api'
import { createDebouncer } from 'promised-debounce'
import useEventActionKey from '@/composables/useEventActionKey'
import useEventEscapeKey from '@/composables/useEventEscapeKey'
import useEventJail from '@/composables/useEventJail'
import i18n from '@/utils/locale'
import {
  defaultsFromMeta
} from '../../_config/'

export const useViewProps = {
  id: {
    type: String
  },
  isClone: {
    type: Boolean
  },
  isNew: {
    type: Boolean
  }
}

export const useView = (props, context) => {

  const {
    id,
    isClone,
    isNew
  } = toRefs(props) // toRefs maintains reactivity w/ destructuring
  const { root: { $store, $router } = {} } = context

  // template refs
  const rootRef = ref(null)

  // state
  let form = ref({})
  let meta = ref({})

  useEventJail(rootRef)

  const actionKey = useEventActionKey(rootRef)
  const escapeKey = useEventEscapeKey(rootRef)
  watch(escapeKey, escapeKey => {
    if (escapeKey)
      doClose()
  })

  const titleLabel = computed(() => {
    switch (true) {
      case !unref(isNew) && !unref(isClone):
        return i18n.t('Role {id}', { id: unref(id) })
      case unref(isClone):
        return i18n.t('Clone Role {id}', { id: unref(id) })
      default:
        return i18n.t('New Role')
    }
  })

  const isLoading = $store.getters['$_roles/isLoading']

  const isDeletable = computed(() => {
      if (unref(isNew) || unref(isClone))
        return false
      const { not_deletable: notDeletable = false } = unref(form) || {}
      if (notDeletable)
        return false
      return true
  })

  const isValid = ref(true)
  let isValidDebouncer
  watch([form, meta], () => {
    isValid.value = false // temporary
    if (!isValidDebouncer)
      isValidDebouncer = createDebouncer()
    isValidDebouncer({
      handler: () => isValid.value = rootRef.value && rootRef.value.querySelectorAll('.is-invalid').length === 0,
      time: 300
    })
  }, { deep: true })

  const doInit = () => {
    $store.dispatch('$_roles/options', id.value).then(options => {
      const { meta: _meta = {} } = options
      meta.value = _meta
      if (isNew.value) // new
        form.value = defaultsFromMeta(meta.value)
    }).catch(() => {
      meta.value = {}
    })
    if (!isNew.value) { // existing
      $store.dispatch('$_roles/getRole', id.value).then(_form => {
        if (isClone.value)
          _form.id = `${_form.id}-${i18n.t('copy')}`
        form.value = _form
      }).catch(() => {
        form.value = {}
      })
    }
  }

  const doCreate = () => {
    const closeAfter = actionKey.value
    $store.dispatch('$_roles/createRole', form.value).then(() => {
      if (closeAfter) // [CTRL] key pressed
        $router.push({ name: 'roles' })
      else
        $router.push({ name: 'role', params: { id: form.value.id } })
    })
  }

  const doClone = () => $router.push({ name: 'cloneRole' })

  const doClose = () => $router.push({ name: 'roles' })

  const doRemove = () => {
    $store.dispatch('$_roles/deleteRole', id.value).then(() => {
      $router.push({ name: 'roles' })
    })
  }

  const doReset = () => doInit()

  const doSave = () => {
    const closeAfter = actionKey.value
    $store.dispatch('$_roles/updateRole', form.value).then(() => {
      if (closeAfter) // [CTRL] key pressed
        $router.push({ name: 'roles' })
    })
  }

  watch(props, () => doInit(), { deep: true, immediate: true })

  return {
    rootRef,

    form,
    meta,
    titleLabel,

    actionKey,
    isLoading,
    isDeletable,
    isValid,

    doInit,
    doCreate,
    doClone,
    doClose,
    doRemove,
    doReset,
    doSave
  }
}
