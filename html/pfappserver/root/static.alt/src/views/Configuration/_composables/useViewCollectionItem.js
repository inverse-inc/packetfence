import { computed, ref, toRefs, watch } from '@vue/composition-api'
import { createDebouncer } from 'promised-debounce'
import useEventActionKey from '@/composables/useEventActionKey'
import useEventEscapeKey from '@/composables/useEventEscapeKey'
import useEventJail from '@/composables/useEventJail'
import i18n from '@/utils/locale'

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
    useCollectionItemDefaults,
    useCollectionItemTitle,
    useCollectionRouter,
    useCollectionStore,
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
  const title = useCollectionItemTitle(props)
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

  const isValid = ref(true)
  let isValidDebouncer
  watch([form, meta], () => {
    isValid.value = false // temporary
    if (!isValidDebouncer)
      isValidDebouncer = createDebouncer()
    isValidDebouncer({
      handler: () => isValid.value = rootRef.value && rootRef.value.querySelectorAll('.is-invalid').length === 0,
      time: 1000
    })
  }, { deep: true })

  const {
    isLoading,
    getOptions,
    createItem,
    deleteItem,
    getItem,
    updateItem,
  } = useCollectionStore(props, context, form)

  const {
    goToCollection,
    goToItem,
    goToClone,
  } = useCollectionRouter(props, context, form)

  const init = () => {
    return new Promise((resolve, reject) => {
      if (!isNew.value) { // existing
        getOptions().then(options => {
          const { meta: _meta = {} } = options
          meta.value = _meta
          getItem().then(item => {
            if (isClone.value) {
              item.id = `${item.id}-${i18n.t('copy')}`
              item.not_deletable = false
            }
            form.value = item
            resolve()
          }).catch(() => {
            form.value = {}
            reject()
          })
        }).catch(() => {
          form.value = {}
          meta.value = {}
          reject()
        })
      } else { // new
        getOptions().then(options => {
          const { meta: _meta = {} } = options
          form.value = useCollectionItemDefaults(_meta, props)
          meta.value = _meta
          resolve()
        }).catch(() => {
          form.value = {}
          meta.value = {}
          reject()
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
