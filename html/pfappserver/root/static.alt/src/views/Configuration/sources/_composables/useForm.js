import { computed, provide, ref, toRefs, unref } from '@vue/composition-api'
import { useFormMetaSchema } from '@/composables/useMeta'
import schemaFn from '../schema'

const useFormProps = {
  form: {
    type: Object
  },
  meta: {
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

  id: {
    type: String
  }
}

const useForm = (props) => {

  const {
    form,
    meta
  } = toRefs(props)

  const sourceType = computed(() => unref(form).type)
  provide('sourceType', sourceType)

  const schema = computed(() => schemaFn(props))

  const metaSchema = computed(() => useFormMetaSchema(meta, schema))

  return {
    schema: metaSchema
  }
}

export {
  useFormProps,
  useForm
}
