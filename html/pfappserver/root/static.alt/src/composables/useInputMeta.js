import { computed, inject, reactive, ref, toRefs, unref, set, watch, watchEffect,
  isReactive, isRef
} from '@vue/composition-api'
import { string, nullable, required } from 'yup'

export const getMetaNamespace = (ns, o) =>
  ns.reduce((xs, x) => (xs && x in xs) ? xs[x] : {}, o)

export const useInputMetaProps = {
  namespace: {
    type: String
  }
}

export const useInputMeta = (props) => {

  const {
    namespace,
    validators
  } = toRefs(props) // toRefs maintains reactivity w/ destructuring

  // defaults (dereferenced)
  let localProps = reactive({ ...props })
  watch(props, (props) => {
    for(let prop in props) {
      set(localProps, prop, props[prop])
    }
  })

  if (unref(namespace)) {
    // use namespace
    const meta = inject('meta', {})
    const namespaceArr = computed(() => unref(namespace).split('.'))
    const namespaceMeta = computed(() => getMetaNamespace(unref(namespaceArr), meta))

    watch(
      namespaceMeta,
      (namespaceMeta) => {
        const {
          placeholder: metaPlaceholder,
          required: metaRequired,
          type: metaType
        } = unref(namespaceMeta)

        // placeholder
        if (metaPlaceholder)
          set(localProps, 'placeholder', metaPlaceholder)

        // validators
        const _validators = unref(validators)
        if (metaRequired && (!_validators || _validators.length === 0)) {
          set(localProps, 'validators', [
            string().nullable().required('Meta required.')
          ])
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
