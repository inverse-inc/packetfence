import { toRefs, unref, computed } from '@vue/composition-api'

export const useInputGroupProps = {
  disabled: {
    type: Boolean,
    default: false
  },
  text: {
    type: String
  }
}

export const useInputGroup = (props) => {

  const {
    disabled,
    text
  } = toRefs(props) // toRefs maintains reactivity w/ destructuring

  // state
  const isLocked = computed(() => unref(disabled))

  return {
    // props
    text,

    //state
    isLocked
  }
}
