import { computed, ref, toRefs, unref, watch, watchEffect } from '@vue/composition-api'

export const useInputValidationProps = {
  state: {
    type: Boolean,
    default: null
  },
  stateMap: {
    type: Object,
    default: () => ({ false: false, true: null }),
    validator: value => ('false' in value && 'true' in value)
  },
  invalidFeedback: {
    type: String
  },
  validFeedback: {
    type: String
  },
  validators: {
    type: Object
  }
}

export const useInputValidation = (props, value) => {

  const {
    state,
    stateMap,
    invalidFeedback,
    validFeedback,
    validators
  } = toRefs(props) // toRefs maintains reactivity w/ destructuring

  // defaults (dereferenced)
  let localState = ref(unref(state))
  let localInvalidFeedback = ref(unref(invalidFeedback))
  let localValidFeedback = ref(unref(validFeedback))

  if (unref(validators)) { // is :validators

    watchEffect(() => {
      const _validators = unref(validators)
      const asyncErrors = Object.keys(_validators)
      if (asyncErrors.length === 0)
        return

      const asyncRules = Object.values(_validators).map(schema => {
        // yup | https://github.com/jquense/yup
        return schema.isValid(unref(value))
      })
      Promise.all(asyncRules).then(results => {
        const invalidFeedbackStack = results.reduce((stack, result, index) => {
          if (result === false)
            stack.push(asyncErrors[index])
          return stack
        }, [])

        if (invalidFeedbackStack.length > 0) {
          localState.value = false
          localValidFeedback.value = null
          localInvalidFeedback.value = invalidFeedbackStack.join(' ')
        }
        else if (unref(validFeedback)) {
          localState.value = true
          localValidFeedback.value = unref(validFeedback)
          localInvalidFeedback.value = null
        }
        else {
          localState.value = null
          localValidFeedback.value = null
          localInvalidFeedback.value = null
        }
      })
    })
  }

  else { // no :validators

    // state
    localState = computed(() => (stateMap && state)
      ? unref(stateMap)[!!unref(state)]
      : null
    )

    // mask :invalidFeedback if :state is truthy or :invalidFeedback is not defined
    localInvalidFeedback = computed(() => (unref(localState) === false && unref(invalidFeedback))
      ? unref(invalidFeedback)
      : null
    )

    // mask :validFeedback if :state is falsey or :validFeedback is not defined
    localValidFeedback = computed(() => (unref(localState) === true && unref(validFeedback))
      ? unref(validFeedback)
      : null
    )
  }

  return {
    state: localState,
    invalidFeedback: localInvalidFeedback,
    validFeedback: localValidFeedback
  }
}
