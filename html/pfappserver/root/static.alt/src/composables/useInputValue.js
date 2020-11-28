import { computed, customRef, inject, nextTick, ref, set, toRefs } from '@vue/composition-api'

export const getFormNamespace = (ns, o) =>
  ns.reduce((xs, x) => (xs && x in xs) ? xs[x] : undefined, o)

export const setFormNamespace = (ns, o, v) => {
  const [ nsf, ...nsr ] = ns
  if (nsr.length) { // recurse
    if (!(nsf && nsf in o))
      set(o, nsf, (+nsr[0] === parseInt(nsr[0]))
        ? [] // o[nsf] = []
        : {} // o[nsf] = {}
      )
    return setFormNamespace(nsr, o[nsf], v)
  }
  else
    set(o, nsf, v) // o[nsf] = v
  return o[nsf]
}

export const useInputValueProps = {
  namespace: {
    type: String
  },
  value: {
    default: null
  }
}


export const useInputValue = (props, { emit }) => {

  const {
    namespace,
    value
  } = toRefs(props) // toRefs maintains reactivity w/ destructuring

  const emitPromise = (eventName, value) => {
    return new Promise((resolve) => {
      emit(eventName, value)
      nextTick(resolve)
    })
  }

  let inputValue = ref(null)
  let onInput
  let onChange
  let onUpdate

  if (namespace.value) {
    // use namespace
    const form = inject('form', ref({}))
    const namespaceArr = computed(() => namespace.value.split('.'))

    inputValue = customRef((track, trigger) => ({
      get() {
        track()
        return getFormNamespace(namespaceArr.value, form.value)
      },
      set(newValue) {
        setFormNamespace(namespaceArr.value, form.value, newValue)
        trigger()
      }
    }))
    onInput = value => new Promise((resolve) => {
      inputValue.value = value
      nextTick(resolve)
    })
    onChange = value => new Promise((resolve) => {
      inputValue.value = value
      nextTick(resolve)
    })
    onUpdate = value => new Promise((resolve) => {
      inputValue.value = value
      nextTick(resolve)
    })
  }
  else {
    // use v-model
    inputValue = value
    onInput = value => new Promise((resolve) => {
      emit('input', value)
      nextTick(resolve)
    })
    onChange = value => new Promise((resolve) => {
      emit('change', value)
      nextTick(resolve)
    })
    onUpdate = value => new Promise((resolve) => {
      emit('update', value)
      nextTick(resolve)
    })
  }

  const inputLength = computed(() => {
    const { length = 0 } = inputValue.value || {}
    return length
  })

  return {
    // props
    value: inputValue,
    length: inputLength,

    //events
    onInput,
    onChange,
    onUpdate
  }
}
