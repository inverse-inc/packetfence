import { toRefs, computed } from '@vue/composition-api'

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
  }
}

export const useInputValidation = (props) => {

  const {
    state,
    stateMap,
    invalidFeedback: propInvalidFeedback,
    validFeedback: propValidFeedback
  } = toRefs(props) // toRefs maintains reactivity w/ destructuring


  // state
  const stateMapped = computed(() => {
    return (stateMap && state)
      ? stateMap.value[!!state.value]
      : null
  })

  // mask :invalidFeedback if :state is truthy or :invalidFeedback is not defined
  const invalidFeedback = computed(() => {
    return (stateMapped.value === false && propInvalidFeedback.value)
      ? propInvalidFeedback.value
      : null
  })

  // mask :validFeedback if :state is falsey or :validFeedback is not defined
  const validFeedback = computed(() => {
    return (stateMapped.value === true && propValidFeedback.value)
      ? propValidFeedback.value
      : null
  })

  return {
    state,
    stateMapped,
    invalidFeedback,
    validFeedback
  }
}
