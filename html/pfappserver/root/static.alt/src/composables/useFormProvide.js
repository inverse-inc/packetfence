import { provide } from '@vue/composition-api'

export const useFormProvideProps = {
  form: {
    type: Object
  },
  meta: {
    type: Object
  }
}

export const useFormProvide = (props) => {
  provide('form', props.form)
  provide('meta', props.meta)
}
