 export const useFormGroupProps = {
  columnLabel: {
    type: String
  },
  labelClass: {
    type: [Array, Object, String]
  },
  labelCols: {
    type: [String, Number],
    default: 3,
    validator: value => (+value >= 1 && +value <= 12)
  }
}
