import { nextTick, provide, ref, toRefs, watch } from '@vue/composition-api'
import { createDebouncer } from 'promised-debounce'

export const useFormProvideProps = {
  form: {
    type: Object
  },
  meta: {
    type: Object
  },
  schema: {
    type: Object
  },
  isLoading: {
    type: Boolean
  }
}

export const useFormProvide = (props) => {

  const {
    form,
    meta,
    schema,
    isLoading
  } = toRefs(props) // toRefs maintains reactivity w/ destructuring

  const lastTick = ref(null)
  let lastTickDebouncer

  watch([form, meta], () => {
    if (!lastTickDebouncer)
      lastTickDebouncer = createDebouncer()
    lastTickDebouncer({
      handler: () => {
console.log('tick')
        lastTick.value = (new Date()).getTime()
      },
      time: 300
    })
  }, { deep: true, immediate: true })

  provide('form', form)
  provide('meta', meta)
  provide('schema', schema)
  provide('isLoading', isLoading)
  provide('lastTick', lastTick)
}
