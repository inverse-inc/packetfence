 export const useFormGroupProps = {
  columnLabel: {
    type: String
  },
  labelCols: {
    type: [String, Number],
    default: 3,
    validator: value => (+value >= 1 && +value <= 12)
  }
}
