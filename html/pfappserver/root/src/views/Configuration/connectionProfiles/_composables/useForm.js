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
  id: {
    type: String
  }
}

const useForm = (props, context) => {

  const {
    meta,
    id,
    isClone
  } = toRefs(props)

  const schema = computed(() => schemaFn(props))

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

  const basesGeneral = computed(() => $store.getters['$_bases/general'])

  const isDefault = computed(() => (id.value === 'default' && !isClone.value))

  return {
    schema: metaSchema,
    basesGeneral,
    isDefault
  }
}

export {
  useFormProps,
  useForm
}
