import { computed, inject, reactive, toRefs, unref, set, watchEffect } from '@vue/composition-api'

export const getMetaNamespace = (ns, o) =>
  ns.reduce((xs, x) => (xs && x in xs) ? xs[x] : {}, o)

export const useInputMetaProps = {
  namespace: {
    type: String
  }
}

export const useInputMeta = (props) => {

  const {
    namespace
  } = toRefs(props) // toRefs maintains reactivity w/ destructuring

  let localProps = reactive(props)

  if (unref(namespace)) {
    // use namespace
    const meta = inject('meta', {})
    const namespaceArr = computed(() => unref(namespace).split('.'))
    const namespaceMeta = computed(() => getMetaNamespace(unref(namespaceArr), meta))

/*
    watch(
      props,
      props => {
        localProps = reactive({ ...props }) // dereference
      },
      { deep: true, immediate: true }
    )
*/

    watchEffect(() => {
      const {
        placeholder: metaPlaceholder
      } = namespaceMeta

      set(localProps, 'placeholder', (metaPlaceholder)
        ? metaPlaceholder
        : props.placeholder
      )

    })
  }

  return localProps
}
