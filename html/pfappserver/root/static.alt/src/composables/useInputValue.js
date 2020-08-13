import { computed, inject, ref, toRefs } from '@vue/composition-api'

export const getFormNamespace = (ns, o) =>
  ns.reduce((xs, x) => (xs && xs[x]) ? xs[x] : null, o)

export const setFormNamespace = (ns, o, v) => {
  const [ nsf, ...nsr ] = ns
  if (!(nsf && nsf in o))
    return
  if (nsr.length)
    setFormNamespace(nsr, o[nsf], v) // recurse
  else
    o[nsf] = v
}

export const useInputValueProps = {
  value: {
    default: null
  },
  namespace: {
    type: String
  }
}

export const useInputValue = (props, { emit }) => {

  const {
    value,
    namespace
  } = toRefs(props) // toRefs maintains reactivity w/ destructuring

  let inputValue = ref(null)
  let onInput
  let onChange

  if (namespace.value) {
    // use namespace
    const form = inject('form', {})
    //const meta = inject('meta', {})
    const namespaceArr = computed(() => namespace.value.split('.'))

    inputValue = computed(() => {
      return getFormNamespace(namespaceArr.value, form)
    })

    onInput = value => {
      setFormNamespace(namespaceArr.value, form, value)
    }
    onChange = value => {
      setFormNamespace(namespaceArr.value, form, value)
    }

    /*
    inputValue = customRef((track, trigger) => {
      return {
        get() {
          track()
          return getFormNamespace(namespaceArr.value, form)
        },
        set(newValue) {
          setFormNamespace(namespaceArr.value, form, newValue)
          trigger()
        }
      }
    })
    */
  }
  else {
    // use v-model
    inputValue = value
    onInput = value => emit('input', value)
    onChange = value => emit('change', value)
  }

  return {
    // props
    value: inputValue,

    //events
    onInput,
    onChange
  }
}
