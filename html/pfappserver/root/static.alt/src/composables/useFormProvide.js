import { provide } from '@vue/composition-api'

export const useFormProvideProps = {
  form: {
    type: Object
  },
  loading: {
    type: Boolean
  },
  meta: {
    type: Object
  },
  schema: {
    type: Object
  }
}

export const useFormProvide = (props) => {
  provide('form', props.form)
  provide('loading', props.loading)

  if(props.meta !== {})
    provide('meta', props.meta)

  if (props.schema !== {})
    provide('schema', props.schema)
}
