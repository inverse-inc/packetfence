import BaseViewTab, { props as BaseViewTabProps } from './BaseViewTab'

const props = {
  ...BaseViewTabProps,

  id: {
    type: String,
    default: 'radius'
  }
}

export default {
  name: 'view-tab-radius',
  extends: BaseViewTab,
  props
}
