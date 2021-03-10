import { toRefs, computed } from '@vue/composition-api'

export const useArrayProps = {
  value: {
    default: null,
    type: [Array, Object]
  }
}

export const useArray = (props, { slots }) => {

  const {
    value
  } = toRefs(props) // toRefs maintains reactivity w/ destructuring

  // state
  const slotsList = computed(() => Object.keys(slots))

  return {
    // props
    value,

    // state
    slotsList
  }
}
