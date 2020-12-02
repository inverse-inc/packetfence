import { computed, ref, toRefs, watch } from '@vue/composition-api'
import { useDebouncedWatchHandler } from '@/composables/useDebounce'
import useEventActionKey from '@/composables/useEventActionKey'
import useEventEscapeKey from '@/composables/useEventEscapeKey'
import useEventJail from '@/composables/useEventJail'


export const useViewCollectionItemProps = {
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

export const useViewCollectionItem = (collection, props, context) => {

  const {
    useItemDefaults = () => ({}), // {}
    useItemTitle = () => {},
    useItemTitleBadge = () => {},
    useRouter = () => {},
    useStore = () => {},
  } = collection

  const {
    isClone,
    isNew
  } = toRefs(props)

  // template refs
  const rootRef = ref(null)
  useEventJail(rootRef)

  // state
  const form = ref({})
  const meta = ref({})
  const title = useItemTitle(props, context, form)
  const titleBadge = useItemTitleBadge(props, context, form)
  const isModified = ref(false)

  // unhandled custom props
  const customProps = ref(context.attrs)

  const isDeletable = computed(() => {
      if (isNew.value || isClone.value)
        return false
      const { not_deletable: notDeletable = false } = form.value || {}
      if (notDeletable)
        return false
      return true
  })

  const isValid = useDebouncedWatchHandler([form, meta], () => (!rootRef.value || rootRef.value.querySelectorAll('.is-invalid').length === 0))

  const {
    isLoading,
    getOptions = () => (new Promise(r => r())),
    createItem,
    deleteItem,
    getItem,
    updateItem,
  } = useStore(props, context, form)

  const {
    goToCollection,
    goToItem,
    goToClone,
  } = useRouter(props, context, form)

  const init = () => {
    return new Promise((resolve, reject) => {
      if (!isNew.value) { // existing
        getOptions().then(options => {
          const { meta: _meta = {} } = options || {}
          meta.value = _meta
          getItem().then(item => {
            form.value = item
            resolve()
          }).catch(e => {
            form.value = {}
            reject(e)
          })
        }).catch(e => {
          form.value = {}
          meta.value = {}
          reject(e)
        })
      } else { // new
        getOptions().then(options => {
          const { meta: _meta = {} } = options || {}
          form.value = useItemDefaults(_meta, props)
          meta.value = _meta
          resolve()
        }).catch(e => {
          form.value = {}
          meta.value = {}
          reject(e)
        })
      }
    })
  }

  const save = () => {
    if (isClone.value || isNew.value)
      return createItem()
    else
      return updateItem()
  }

  const onClose = () => goToCollection()

  const onClone = () => goToClone()

  const onRemove = () => deleteItem().then(() => goToCollection())

  const onReset = () => init().then(() => isModified.value = false)

  const actionKey = useEventActionKey(rootRef)
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

  const escapeKey = useEventEscapeKey(rootRef)
  watch(escapeKey, () => goToCollection())

  watch(props, () => init(), { deep: true, immediate: true })

  return {
    rootRef,
    form,
    meta,
    title,
    isModified,
    customProps,
    actionKey,
    isDeletable,
    isValid,
    isLoading,
    onClose,
    onClone,
    onRemove,
    onReset,
    onSave,

    // to overload
    scopedSlotProps: props,
    titleBadge: undefined
  }
}
