import { ref, watch } from '@vue/composition-api'
import { useDebouncedWatchHandler } from '@/composables/useDebounce'
import useEventJail from '@/composables/useEventJail'
import { usePropsWrapper } from '@/composables/useProps'

export const useViewCollectionItemFixedProps = {
  id: {
    type: String
  }
}

export const useViewCollectionItemFixed = (collection, props, context) => {

  const {
    useItemTitle,
    useStore: _useStore = () => {},
  } = collection

  // merge props w/ params in useStore methods
  const useStore = $store => usePropsWrapper(_useStore($store), props)

  const { root: { $store } = {} } = context

  // template refs
  const rootRef = ref(null)
  useEventJail(rootRef)

  // state
  const form = ref({})
  const title = useItemTitle(props, context, form)
  const isModified = ref(false)

  // unhandled custom props
  const customProps = ref(context.attrs)

  const isDeletable = false

  const isValid = useDebouncedWatchHandler(
    form,
    () => (
      !rootRef.value ||
      Array.prototype.slice.call(rootRef.value.querySelectorAll('.is-invalid'))
        .filter(el => el.closest('fieldset').style.display !== 'none') // handle v-show <.. style="display: none;">
        .length === 0
    )
  )

  const {
    isLoading,
    getItem,
    updateItem,
  } = useStore($store)

  const init = () => {
    return new Promise((resolve, reject) => {
      getItem().then(item => {
        form.value = { ...item } // dereferenced
        resolve()
      }).catch(e => {
        form.value = {}
        reject(e)
      })
    })
  }

  const onReset = () => init().then(() => isModified.value = false)

  const onSave = () => {
    isModified.value = true
    return updateItem(form.value)
  }

  watch(props, () => init(), { deep: true, immediate: true })

  return {
    rootRef,
    form,
    title,
    isModified,
    customProps,
    isDeletable,
    isValid,
    isLoading,
    onReset,
    onSave,

    // to overload
    scopedSlotProps: props,
    titleBadge: undefined
  }
}
