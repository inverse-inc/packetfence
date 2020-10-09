import { computed, inject, ref, toRefs, unref, watch } from '@vue/composition-api'
import { createDebouncer } from 'promised-debounce'
import { object, reach } from 'yup'
import i18n, { formatter } from '@/utils/locale'

export const useInputValidatorProps = {
  namespace: {
    type: String
  },
  state: {
    type: Boolean,
    default: null
  },
  invalidFeedback: {
    type: String,
    default: undefined
  },
  validFeedback: {
    type: String,
    default: undefined
  },
  validator: {
    type: Object
  }
}

export const useInputValidator = (props, value) => {

  const {
    namespace,
    state,
    invalidFeedback,
    validFeedback,
    validator
  } = toRefs(props) // toRefs maintains reactivity w/ destructuring

  // defaults (dereferenced)
  let localState = ref(unref(state))
  let localInvalidFeedback = ref(unref(invalidFeedback))
  let localValidFeedback = ref(unref(validFeedback))
  let localValidator = ref(unref(validator))

  if (unref(namespace)) { // is :namespace
    // use namespace
    const schema = inject('schema')

    // recompose namespace into yup path (eg: array.1 => array[1])
    const path = computed(() => unref(namespace).split('.').reduce((path, part) => {
      return (`${+part}` === `${part}`)
        ? [ ...path.slice(0, path.length -1), `${path[path.length - 1]}[${part}]` ]
        : [ ...path, part ]
    }, []).join('.'))

    localValidator = computed(() => {
      /**
       * reach throws an exception when a path is not defined in the schema
       * https://github.com/jquense/yup/issues/599
      **/
      try {
        const namespaceSchema = reach(unref(schema), unref(path))
        if (unref(validator))
          return unref(validator).concat(namespaceSchema) // merge schemas
        else
          return namespaceSchema
      } catch (e) { // path not defined in schema
        if (unref(validator))
          return unref(validator) // fallback to prop
        return object().nullable() // fallback to placeholder
      }
    })
  }

  if (unref(localValidator)) { // is :validator

    let lastPromise = 0 // only use latest of 1+ promises
    const setState = (thisPromise, state, validFeedback, invalidFeedback) => {
      if (thisPromise === lastPromise) {
        localState.value = state
        localValidFeedback.value = validFeedback
        localInvalidFeedback.value = invalidFeedback
      }
    }

    let validateDebouncer
    watch(
      [value, localValidator],
      () => {
        const schema = unref(localValidator)
        const thisPromise = ++lastPromise

        if (!validateDebouncer)
          validateDebouncer = createDebouncer()

        validateDebouncer({
          handler: () => {
            // yup | https://github.com/jquense/yup
            schema.validate(unref(value)).then(() => { // valid
              if (unref(validFeedback) !== undefined)
                setState(thisPromise, true, unref(validFeedback), null)
              else
                setState(thisPromise, null, null, null)
            }).catch(({ message }) => { // invalid
              const { type = 'string', meta, meta: { invalidFeedback: metaInvalidFeedback } = {} } = schema.describe()
              if (metaInvalidFeedback) // meta feedback masks child error messages
                setState(thisPromise, false, null, metaInvalidFeedback)
              else {
                switch (type) { // interpolate message w/ meta[fieldName]
                  case 'array':
                  case 'object':
                    message = formatter.interpolate(message, { fieldName: i18n.t('Item'), ...meta })[0]
                    break
                  case 'mixed':
                  case 'string':
                    message = formatter.interpolate(message, { fieldName: i18n.t('Value'), ...meta })[0]
                    break
                }
                setState(thisPromise, false, null, message)
              }
            })
          },
          time: 300
        })
      },
      { deep: true, immediate: true }
    )
  }
  else { // no :validator
    localInvalidFeedback = invalidFeedback
    localValidFeedback = validFeedback
    localState = computed(() => {
      if (unref(state) !== false)
        return (unref(validFeedback) !== undefined)
          ? true // is validFeedback
          : null // no validFeeback
      return false
    })
  }

  return {
    state: localState,
    invalidFeedback: localInvalidFeedback,
    validFeedback: localValidFeedback
  }
}
