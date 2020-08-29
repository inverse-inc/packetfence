import { computed, reactive, ref, toRefs, unref, watch } from '@vue/composition-api'
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

export const useView = (props, { root: { $router, $store } = {} } ) => {
  const {
    id,
    isClone,
    isNew
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

  const init = () => {
    $store.dispatch('$_roles/options', unref(id)).then(options => {
      const { meta: _meta = {} } = options
      meta.value = _meta
      if (!unref(id)) // new
        form.value = defaultsFromMeta(meta.value)
    }).catch(() => {
      meta.value = {}
    })
    if (unref(id)) { // exissting
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
        // noop
        break

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

  watch(props, (props) => init(), { deep: true, immediate: true })

  return {
    rootRef,

    isClone,
    isNew,
    isLoading,
    isDeletable,

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
