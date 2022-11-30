import TheTab, { props as TheTabProps } from './TheTab'

const props = {
  ...TheTabProps,

  id: {
    type: String,
    default: 'http'
  },
  class: {
    type: String,
    default: 'no-saas'
  },
  titleItemClass: {
    type: String,
    default: 'no-saas'
  }
}

export default {
  name: 'tab-http',
  extends: TheTab,
  props
}
