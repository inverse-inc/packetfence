import { computed, ref, watch } from '@vue/composition-api'
import { useDebouncedWatchHandler } from '@/composables/useDebounce'
import useEventJail from '@/composables/useEventJail'

export const useViewResourceProps = {}

export const useViewResource = (resource, props, context) => {

  const {
    useTitle,
    useTitleHelp = () => {},
    useStore,
  } = resource

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

  const isValid = useDebouncedWatchHandler([form, meta], () => (!rootRef.value || rootRef.value.querySelectorAll('.is-invalid').length === 0))

  const {
    isLoading,
    getOptions,
    getItem,
    updateItem,
  } = useStore(props, context, form)

  const isSaveable = computed(() => !!updateItem)

  const init = () => {
    return new Promise((resolve, reject) => {
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
    })
  }

  const save = () => updateItem()

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
