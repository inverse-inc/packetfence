import { computed, ref, watch } from '@vue/composition-api'
import { useDebouncedWatchHandler } from '@/composables/useDebounce'
import useEventJail from '@/composables/useEventJail'
import { usePropsWrapper } from '@/composables/useProps'

export const useViewResourceProps = {}

export const useViewResource = (resource, props, context) => {

  const {
    useTitle,
    useTitleHelp = () => {},
    useStore: _useStore = () => {},
  } = resource

  // merge props w/ params in useStore methods
  const useStore = $store => usePropsWrapper(_useStore($store), props)

  const { root: { $store } = {} } = context

  // template refs
  const rootRef = ref(null)
  useEventJail(rootRef)

  // state
  const form = ref({})
  const meta = ref({})
  const title = useTitle(props)
  const titleHelp = useTitleHelp(props)
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
    getItemOptions = () => (new Promise(r => r())),
    getItem,
    updateItem,
  } = useStore($store)
  const isSaveable = computed(() => !!updateItem)

  const init = () => {
    return new Promise((resolve, reject) => {
      getItemOptions().then(options => {
        const { meta: _meta = {} } = options || {}
        meta.value = _meta
        getItem().then(item => {
          form.value = { ...item } // dereferenced
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
    })
  }

  const save = () => updateItem(form.value)

  const onReset = () => init().then(() => isModified.value = false)

  const onSave = () => {
    isModified.value = true
    save()
  }

  watch(props, () => init(), { deep: true, immediate: true })

  return {
    rootRef,
    form,
    meta,
    title,
    titleHelp,
    isModified,
    customProps,
    isLoading,
    isSaveable,
    isValid,
    onReset,
    onSave,

    // to overload
    scopedSlotProps: props
  }
}
