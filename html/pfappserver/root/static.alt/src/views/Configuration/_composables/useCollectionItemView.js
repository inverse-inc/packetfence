import { ref, toRefs, watch } from '@vue/composition-api'
import { createDebouncer } from 'promised-debounce'
import useEventActionKey from '@/composables/useEventActionKey'
import useEventEscapeKey from '@/composables/useEventEscapeKey'
import useEventJail from '@/composables/useEventJail'

export const useCollectionItemProps = {
  id: {
    type: String
  },
  isClone: {
    type: Boolean
  },
  isNew: {
    type: Boolean
  },
}

export const useCollectionItemView = (useCollectionItemFn, props, context) => {

  const {
    id,
  } = toRefs(props)

  // template refs
  const rootRef = ref(null)
  useEventJail(rootRef)

  // state
  const form = ref({})
  const meta = ref({})
  const isModified = ref(false)

  // unhandled custom props
  const customProps = ref(context.attrs)

  // state
  const actionKey = useEventActionKey(rootRef)
  const escapeKey = useEventEscapeKey(rootRef)

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


  const collectionItem = useCollectionItemFn(props, context, form, meta)
  const {
    reset,
    remove,
    save,
    goToCollection,
    goToItem,
    goToClone,
  } = collectionItem

  const onClose = () => goToCollection()

  const onClone = () => goToClone(id.value)

  const onRemove = () => remove().then(() => goToCollection())

  const onReset = () => reset().then(() => isModified.value = false)

  const onSave = () => {
    isModified.value = true
    const closeAfter = actionKey.value
    save().then(() => {
      if (closeAfter) // [CTRL] key pressed
        goToCollection()
      else
        goToItem(form.value.id)
    })
  }

  watch(escapeKey, () => goToCollection())

  return {
    rootRef,
    form,
    meta,
    isModified,
    customProps,
    actionKey,
    escapeKey,
    isValid,

    ...collectionItem,

    onClose,
    onClone,
    onRemove,
    onReset,
    onSave,
  }
}
