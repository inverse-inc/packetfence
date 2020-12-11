import BaseViewTab, { props as BaseViewTabProps } from './BaseViewTab'

const props = {
  ...BaseViewTabProps,

  id: {
    type: String,
    default: 'http'
  }
}

export default {
  name: 'view-tab-http',
  extends: BaseViewTab,
  props
}
