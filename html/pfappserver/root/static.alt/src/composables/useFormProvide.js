import { provide } from '@vue/composition-api'

export const useFormProvideProps = {
  form: {
    type: Object
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

  if(props.meta !== {})
    provide('meta', props.meta)

  if (props.schema !== {})
    provide('schema', props.schema)
}
