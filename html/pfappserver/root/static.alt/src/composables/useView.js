import { computed, ref, toRefs, unref, watch } from '@vue/composition-api'
import { useDebouncedWatchHandler } from '@/composables/useDebounce'
import useEventActionKey from '@/composables/useEventActionKey'
import useEventEscapeKey from '@/composables/useEventEscapeKey'
import useEventJail from '@/composables/useEventJail'

export const useViewProps = {
  isClone: {
    type: Boolean
  },
  isNew: {
    type: Boolean
  }
}

export const useView = (props, context) => {

  const {
    isClone,
    isNew
  } = toRefs(props) // toRefs maintains reactivity w/ destructuring

  // template refs
  const rootRef = ref(null)
  useEventJail(rootRef)

  // state
  const form = ref({})
  const meta = ref({})

  // unhandled custom props
  const customProps = ref(context.attrs)

  // state
  const actionKey = useEventActionKey(rootRef)
  const escapeKey = useEventEscapeKey(rootRef)
  const isDeletable = computed(() => {
      if (unref(isNew) || unref(isClone))
        return false
      const { not_deletable: notDeletable = false } = unref(form) || {}
      if (notDeletable)
        return false
      return true
  })

  const isValid = useDebouncedWatchHandler([form, meta], () => (!rootRef.value || rootRef.value.querySelectorAll('.is-invalid').length === 0))

  return {
    rootRef,

    form,
    meta,
    customProps,
    actionKey,
    escapeKey,
    isDeletable,
    isValid
  }
}
