import { toRefs, computed } from '@vue/composition-api'

export const useInputValidationProps = {
  state: {
    type: Boolean,
    default: null
  },
  stateMap: {
    type: Object,
    default: () => ({ false: false, true: null })
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
    invalidFeedback,
    validFeedback
  } = toRefs(props) // toRefs maintains reactivity w/ destructuring

  // state
  const stateMapped = computed(() => {
    return (stateMap && state)
      ? stateMap.value[!!state.value]
      : null
  })

  // mask :invalidFeedback if :state is truey or :invalidFeedback is not defined
  const maskInvalidFeedback = computed(() => {
    return (stateMapped.value === false && invalidFeedback.value)
      ? invalidFeedback.value
      : null
  })

  // mask :validFeedback if :state is falsey or :validFeedback is not defined
  const maskValidFeedback = computed(() => {
    return (stateMapped.value === true && validFeedback.value)
      ? validFeedback.value
      : null
  })

  return {
    state,
    stateMapped,
    invalidFeedback: maskInvalidFeedback,
    validFeedback: maskValidFeedback
  }
}
