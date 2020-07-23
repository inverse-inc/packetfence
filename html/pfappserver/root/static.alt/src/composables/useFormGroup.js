import { toRefs } from '@vue/composition-api'

export const useFormGroupProps = {
  columnLabel: {
    type: String
  },
  labelCols: {
    type: [String, Number],
    default: 3,
    validator: (value) => (parseInt(value) >= 0 && parseInt(value) <= 12)
  },
  text: {
    type: String
  }
}

export const useFormGroup = (props) => {

  const {
    columnLabel,
    labelCols,
    text
  } = toRefs(props) // toRefs maintains reactivity w/ destructuring

  return {
    columnLabel,
    labelCols,
    text
  }
}
