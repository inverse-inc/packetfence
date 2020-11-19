import { ref, watch } from '@vue/composition-api'
import { createDebouncer } from 'promised-debounce'
import useEventJail from '@/composables/useEventJail'

export const useViewResourceProps = {}

export const useViewResource = (resource, props, context) => {

  const {
    useResourceTitle,
    useResourceStore,
  } = resource

  // template refs
  const rootRef = ref(null)
  useEventJail(rootRef)

  // state
  const form = ref({})
  const meta = ref({})
  const title = useResourceTitle(props)
  const isModified = ref(false)

  // unhandled custom props
  const customProps = ref(context.attrs)

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
    getItem,
    updateItem,
  } = useResourceStore(props, context, form)

  const init = () => {
    return new Promise((resolve, reject) => {
      getOptions().then(options => {
        const { meta: _meta = {} } = options
        meta.value = _meta
        getItem().then(item => {
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
    isModified,
    customProps,
    isValid,
    isLoading,
    onReset,
    onSave,

    // to overload
    scopedSlotProps: props
  }
}
