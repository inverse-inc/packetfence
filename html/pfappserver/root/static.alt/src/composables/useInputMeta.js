import { computed, inject, reactive, ref, toRefs, unref, set, watch } from '@vue/composition-api'
import yup from '@/utils/yup'

export const getMetaNamespace = (ns, o) =>
  ns.reduce((xs, x) => (xs && x in xs) ? xs[x] : {}, o)

export const useInputMetaProps = {
  namespace: {
    type: String
  },
  validator: {
    type: Object
  }
}

export const useInputMeta = (props) => {

  const {
    namespace,
    validator
  } = toRefs(props) // toRefs maintains reactivity w/ destructuring

  // defaults (dereferenced)
  let localProps = reactive({})
  watch(
    props,
    props => {
      for(let prop in props) {
        set(localProps, prop, props[prop])
      }
    },
    { immediate: true }
  )

  if (unref(namespace)) {
    // use namespace
    const meta = inject('meta', ref({}))
    const namespaceArr = computed(() => unref(namespace).split('.'))
    const namespaceMeta = computed(() => getMetaNamespace(unref(namespaceArr), unref(meta)))

    watch(
      namespaceMeta,
      namespaceMeta => {
        let _namespaceMeta = unref(namespaceMeta)
        let { type, item } = _namespaceMeta
        if (type === 'array')
          _namespaceMeta = item
        const {
          allowed: metaAllowed,
          min_length: metaMinLength = undefined,
          max_length: metaMaxLength = undefined,
          min_value: metaMinValue = undefined,
          max_value: metaMaxValue = undefined,
          pattern: metaPattern,
          placeholder: metaPlaceholder,
          required: metaRequired,
          type: metaType
        } = _namespaceMeta

        // allowed
        if (metaAllowed) {
          set(localProps, 'options', metaAllowed)
        }

        // placeholder
        if (metaPlaceholder)
          set(localProps, 'placeholder', metaPlaceholder)

        // validator
        if (!unref(validator)) {
          let schema = yup.string().nullable()

          if (metaRequired)
            schema = schema.required()

          if (metaPattern) {
            const { regex, message } = metaPattern
            const re = new RegExp(`^${regex}$`)
            schema = schema.matches(re, message)
          }

          if (metaMinLength !== undefined)
            schema = schema.min(metaMinLength)

          if (metaMaxLength !== undefined)
            schema = schema.max(metaMaxLength)

          if (metaMinValue !== undefined)
            schema = schema.minAsInt(metaMinValue)

          if (metaMaxValue !== undefined)
            schema = schema.maxAsInt(metaMaxValue)

          set(localProps, 'validator', schema)
        }

        // type
        switch(metaType) {
          case 'integer':
            set(localProps, 'type', 'number')
            break
          default:
            set(localProps, 'type', 'text')
        }
      },
      { immediate: true }
    )
  }

  return localProps
}
