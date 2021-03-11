import { provide, toRefs } from '@vue/composition-api'

export const useFormProvideProps = {
  form: {
    type: Object,
    default: () => ({})
  },
  meta: {
    type: Object,
    default: () => ({})
  },
  schema: {
    type: Object
  },
  isLoading: {
    type: Boolean
  },
  isReadonly: {
    type: Boolean
  }
}

export const useFormProvide = (props) => {
  const {
    form,
    meta,
    schema,
    isLoading,
    isReadonly
  } = toRefs(props) // toRefs maintains reactivity w/ destructuring

  provide('form', form)
  provide('meta', meta)
  provide('schema', schema)
  provide('isLoading', isLoading)
  provide('isReadonly', isReadonly)
}
