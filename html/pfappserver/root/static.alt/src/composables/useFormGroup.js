import { toRefs } from '@vue/composition-api'

export const useFormGroupProps = {
  columnLabel: {
    type: String
  },
  labelCols: {
    type: [String, Number],
    default: 3,
    validator: (value) => (+value >= 1 && +value <= 12)
  }
}

export const useFormGroup = (props) => {

  const {
    columnLabel,
    labelCols,
  } = toRefs(props) // toRefs maintains reactivity w/ destructuring

  return {
    columnLabel,
    labelCols
  }
}
