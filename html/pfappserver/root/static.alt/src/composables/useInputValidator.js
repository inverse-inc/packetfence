import { computed, inject, ref, toRefs, unref, watch, watchEffect } from '@vue/composition-api'
import { object, nullable, reach } from 'yup'

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
    const schema = inject('schema', {})

    localValidator = computed(() => {
      /**
       * reach throws an exception when a path is not defined in the schema
       * https://github.com/jquense/yup/issues/599
      **/
      try {
        return reach(schema, unref(namespace))
      } catch (e) { // path not defined in schema
        if (unref(validator))
          return unref(validator) // fallback to prop
        return object().nullable() // fallback to placeholder
      }
    })
  }

  if (unref(localValidator)) { // is :validator

    watchEffect(() => {
      const schema = unref(localValidator)

      // yup | https://github.com/jquense/yup
      schema.validate(unref(value)).then(() => { // valid
        if (unref(validFeedback) !== undefined) {
          localState.value = true
          localValidFeedback.value = unref(validFeedback)
          localInvalidFeedback.value = null
        }
        else {
          localState.value = null
          localValidFeedback.value = null
          localInvalidFeedback.value = null
        }
      }).catch(({ message }) => { // invalid
        localState.value = false
        localValidFeedback.value = null
        localInvalidFeedback.value = message
      })
    })
  }
  else { // no :validator

    localInvalidFeedback = invalidFeedback
    localValidFeedback = validFeedback
    localState = computed(() => {
      if (unref(state) === true)
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
