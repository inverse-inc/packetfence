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
  actionKeyButtonVerb: {
    type: String
  }
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

  const isValid = useDebouncedWatchHandler(
    [form, meta],
    () => (
      !rootRef.value ||
      Array.prototype.slice.call(rootRef.value.querySelectorAll('.is-invalid'))
        .filter(el => el.closest('fieldset').style.display !== 'none') // handle v-show <.. style="display: none;">
        .length === 0
    )
  )

  const {
    isLoading,
    getOptions = () => (new Promise(r => r())),
    createItem,
    deleteItem,
    getItem,
    updateItem,
  } = useStore(props, context, form)

  const isSaveable = computed(() => {
    if (isNew.value || isClone.value)
      return !!createItem
    return !!updateItem
  })

  const {
    goToCollection,
    goToItem,
    goToClone,
  } = useRouter(props, context, form)

  const isCloneable = computed(() => !!goToClone)

  const isDeletable = computed(() => {
      if (isNew.value || isClone.value)
        return false
      if (!deleteItem)
        return false
      const { not_deletable: notDeletable = false } = form.value || {}
      if (notDeletable)
        return false
      return true
  })

  const init = () => {
    return new Promise((resolve, reject) => {
      if (!isNew.value) { // existing
        getOptions().then(options => {
          const { meta: _meta = {} } = options || {}
          meta.value = _meta
          getItem().then(item => {
            form.value = { ...item } // dereferenced
            resolve()
          }).catch(e => {
            form.value = {}
            reject(e)
          })
        }).catch(() => { // meta may not be available, fail silently
          meta.value = {}
          getItem().then(item => {
            form.value = { ...item } // dereferenced
            resolve()
          }).catch(e => {
            form.value = {}
            reject(e)
          })
        })
      } else { // new
        getOptions().then(options => {
          const { meta: _meta = {} } = options || {}
          form.value = useItemDefaults(_meta, props, context)
          meta.value = _meta
          resolve()
        }).catch(() => {
          form.value = {}
          meta.value = {}
          resolve() // meta may not be available, fail silently
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
    save().then(response => {
      if (closeAfter) // [CTRL] key pressed
        goToCollection(true)
      else {
        form.value = { ...form.value, ...response } // merge form w/ newly inserted IDs
        goToItem().then(() => init()) // re-init
      }
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
    titleBadge,
    isModified,
    customProps,
    actionKey,
    isCloneable,
    isDeletable,
    isSaveable,
    isValid,
    isLoading,
    onClose,
    onClone,
    onRemove,
    onReset,
    onSave,

    // to overload
    scopedSlotProps: props
  }
}
