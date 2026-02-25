import TheTab, { props as TheTabProps } from './TheTab'

const props = {
  ...TheTabProps,

  id: {
    type: String,
    default: 'http'
  },
  titleItemClass: {
    type: String
  }
}

export default {
  name: 'tab-http',
  extends: TheTab,
  props
}
