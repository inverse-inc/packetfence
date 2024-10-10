import { computed, onMounted, provide, ref, toRefs } from '@vue/composition-api'
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
  collection: {
    type: String
  },
  id: {
    type: String
  },
  type: {
    type: String
  },
}

const useForm = (props, context) => {

  const {
    meta
  } = toRefs(props)

  const schema = computed(() => schemaFn(props))

  // meta indicates which fields are preset
  const fields = computed(() => Object.keys(meta.value))

  const metaSchema = computed(() => useFormMetaSchema(meta, schema))

  const { root: { $store } = {} } = context

  // provide RADIUS attributes to all child nodes
  const radiusAttributes = ref({})
  provide('radiusAttributes', radiusAttributes)
  onMounted(() => {
    $store.dispatch('radius/getAttributes').then(_radiusAttributes => {
      radiusAttributes.value = _radiusAttributes
    })
  })

  return {
    fields,
    schema: metaSchema
  }
}

export {
  useFormProps,
  useForm
}
