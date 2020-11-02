import { computed, inject, ref, toRefs, unref, watch } from '@vue/composition-api'
import { createDebouncer } from 'promised-debounce'
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

export const useInputValidator = (props, value, recursive = false) => {

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

  // yup | https://github.com/jquense/yup
  let localValidator = ref(unref(validator))

  let form = ref(undefined)
  let path = ref(undefined)

  if (namespace.value) { // is :namespace

    // recompose namespace into yup path (eg: array.1 => array[1])
    path = computed(() => namespace.value.split('.').reduce((path, part) => {
      return (`${+part}` === `${part}`)
        ? [ ...path.slice(0, path.length -1), `${path[path.length - 1]}[${part}]` ]
        : [ ...path, part ]
    }, []).join('.'))

    form = inject('form')
    localValidator = inject('schema')

    /*
    localValidator = computed(() => {
      return schema.value
      // reach throws an exception when a path is not defined in the schema
      //  https://github.com/jquense/yup/issues/599
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
    */
  }

  if (localValidator.value) { // is :validator

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
            let validationPromise
            if (namespace.value) { // use namespace/path
              // yup throws an exception when a path is not defined in the schema
              //  https://github.com/jquense/yup/issues/599
              try {
                validationPromise = schema.validateAt(path.value, form.value, { recursive })
              } catch (e) { // path not defined in schema
                validationPromise = true
              }
            }
            else { // use value
              validationPromise = schema.validate(value.value, { recursive })
            }
            Promise.resolve(validationPromise).then(() => { // valid
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
