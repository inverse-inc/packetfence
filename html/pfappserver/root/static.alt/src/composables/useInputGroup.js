import { toRefs } from '@vue/composition-api'

export const useInputGroupProps = {
  text: {
    type: String
  }
}

export const useInputGroup = (props) => {

  const {
    text
  } = toRefs(props) // toRefs maintains reactivity w/ destructuring

  return {
    // props
    text
  }
}
