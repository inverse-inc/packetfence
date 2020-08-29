import { computed, ref, toRefs, unref, watch } from '@vue/composition-api'
import { createDebouncer } from 'promised-debounce'
import useEventEscapeKey from '@/composables/useEventEscapeKey'
import useEventJail from '@/composables/useEventJail'
import i18n from '@/utils/locale'

export const defaultsFromMeta = (meta = {}) => {
  let defaults = {}
  Object.keys(meta).forEach(key => {
    if ('properties' in meta[key]) { // handle dot-notation keys ('.')
      Object.keys(meta[key].properties).forEach(property => {
        if (!(key in defaults)) {
          defaults[key] = {}
        }
        // default w/ object
        defaults[key][property] = meta[key].properties[property].default
      })
    } else {
      defaults[key] = meta[key].default
    }
  })
  return defaults
}

export const useViewProps = {
  id: {
    type: String
  },
  isClone: {
    type: Boolean
  },
  isNew: {
    type: Boolean
  },
  titleLabelisNone: {
    type: Function,
    default: id => i18n.t('{id}', { id })
  },
  titleLabelisClone: {
    type: Function,
    default: id => i18n.t('Clone {id}', { id })
  },
  titleLabelisNew: {
    type: Function,
    default: () => i18n.t('New')
  }
}

export const useView = (props, { root: { $router, $store } = {} }) => {

  const {
    id,
    isClone,
    isNew,
    titleLabelisNone,
    titleLabelisClone,
    titleLabelisNew
  } = toRefs(props) // toRefs maintains reactivity w/ destructuring

  // template refs
  const rootRef = ref(null)

  // state
  let form = ref({})
  let meta = ref({})

  useEventJail(rootRef)

  const escapeKey = useEventEscapeKey(rootRef)
  watch(escapeKey, escapeKey => {
    if (escapeKey)
      doClose()
  })

  const isDeletable = computed(() => {
      if (unref(isNew) || unref(isClone))
        return false
      const { not_deletable: notDeletable = false } = unref(form) || {}
      if (notDeletable)
        return false
      return true
  })

  const isLoading = $store.getters['$_roles/isLoading']

  const isValid = ref(true)
  let isValidDebouncer
  watch([form, meta], () => {
    isValid.value = false // temporary
    if (!isValidDebouncer)
      isValidDebouncer = createDebouncer()
    isValidDebouncer({
      handler: () => isValid.value = rootRef.value.querySelectorAll('.is-invalid').length === 0,
      time: 300
    })
  }, { deep: true })

  const titleLabel = computed(() => {
    switch (true) {
      case !unref(isNew) && !unref(isClone):
        return titleLabelisNone.value(unref(id))
      case unref(isClone):
        return titleLabelisClone.value(unref(id))
      default:
        return titleLabelisNew.value()
    }
  })

  const init = () => {
    $store.dispatch('$_roles/options', unref(id)).then(options => {
      const { meta: _meta = {} } = options
      meta.value = _meta
      if (!unref(id)) // new
        form.value = defaultsFromMeta(meta.value)
    }).catch(() => {
      meta.value = {}
    })
    if (unref(id)) { // existing
      $store.dispatch('$_roles/getRole', unref(id)).then(_form => {
        if (unref(isClone))
          _form.id = `${_form.id}-${i18n.t('copy')}`
        form.value = _form
      }).catch(() => {
        form.value = {}
      })
    }
  }

  const doClone = () => $router.push({ name: 'cloneRole' })
  const doClose = () => $router.push({ name: 'roles' })
  const doRemove = () => {
    $store.dispatch('$_roles/deleteRole', unref(id)).then(() => {
      doClose()
    })
  }
  const doReset = () => init()
  const doSave = (actionKey) => {
    switch (true) {
      case !unref(isNew) && !unref(isClone): // save
        $store.dispatch('$_roles/updateRole', unref(form)).then(() => {
          if (actionKey) // [CTRL] key pressed
            doClose()
        })
        break

      case unref(isClone): // clone
      default: // create
        $store.dispatch('$_roles/createRole', unref(form)).then(() => {
          if (actionKey) // [CTRL] key pressed
            doClose()
          else
            $router.push({ name: 'role', params: { id: unref(form).id } })
        })
        break
    }
  }

  watch(props, () => init(), { deep: true, immediate: true })

  return {
    rootRef,

    isClone,
    isNew,
    isLoading,
    isDeletable,
    isValid,

    titleLabel,
    form,
    meta,

    doClone,
    doClose,
    doRemove,
    doReset,
    doSave

  }
}
