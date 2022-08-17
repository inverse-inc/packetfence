 export const useFormGroupProps = {
  columnLabel: {
    type: String
  },
  contentCols: {
    type: [Boolean, String, Number],
    default: true, // auto
    validator: value => ([true, false].includes(value) || (+value >= 1 && +value <= 12))
  },
  contentColsSm: {
    type: [Boolean, String, Number],
    default: true, // auto
    validator: value => ([true, false].includes(value) || (+value >= 1 && +value <= 12))
  },
  contentColsMd: {
    type: [Boolean, String, Number],
    default: true, // auto
    validator: value => ([true, false].includes(value) || (+value >= 1 && +value <= 12))
  },
  contentColsLg: {
    type: [Boolean, String, Number],
    default: true, // auto
    validator: value => ([true, false].includes(value) || (+value >= 1 && +value <= 12))
  },
  contentColsXl: {
    type: [Boolean, String, Number],
    default: true, // auto
    validator: value => ([true, false].includes(value) || (+value >= 1 && +value <= 12))
  },
  labelClass: {
    type: [Array, Object, String]
  },
  labelCols: {
    type: [Boolean, String, Number],
    default: 3,
    validator: value => ([true, false].includes(value) || (+value >= 1 && +value <= 12))
  },
  labelColsMd: {
    type: [Boolean, String, Number],
    default: 3,
    validator: value => ([true, false].includes(value) || (+value >= 1 && +value <= 12))
  },
  labelColsSm: {
    type: [Boolean, String, Number],
    default: 3,
    validator: value => ([true, false].includes(value) || (+value >= 1 && +value <= 12))
  },
  labelColsLg: {
    type: [Boolean, String, Number],
    default: 3,
    validator: value => ([true, false].includes(value) || (+value >= 1 && +value <= 12))
  },
  labelColsXl: {
    type: [Boolean, String, Number],
    default: 3,
    validator: value => ([true, false].includes(value) || (+value >= 1 && +value <= 12))
  }
}
