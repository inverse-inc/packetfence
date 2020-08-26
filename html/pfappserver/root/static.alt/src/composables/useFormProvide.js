import { provide, toRefs } from '@vue/composition-api'

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

  provide('form', form)
  provide('meta', meta)
  provide('schema', schema)
  provide('isLoading', isLoading)

}
