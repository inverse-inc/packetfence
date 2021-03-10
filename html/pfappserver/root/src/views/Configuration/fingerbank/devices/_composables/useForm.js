import { computed } from '@vue/composition-api'
import schemaFn from '../schema'

const useFormProps = {
  form: {
    type: Object
  },
  isNew: {
    type: Boolean,
    default: false
  },
  isClone: {
    type: Boolean,
    default: false
  },
  isLoading: {
    type: Boolean,
    default: false
  },
  scope: {
    type: String
  }
}

const useForm = (props) => {

  const schema = computed(() => schemaFn(props))

  return {
    schema
  }
}

export {
  useFormProps,
  useForm
}
