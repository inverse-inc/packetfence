import TheTab, { props as TheTabProps } from './TheTab'

const props = {
  ...TheTabProps,

  id: {
    type: String,
    default: 'radius'
  }
}

export default {
  name: 'tab-radius',
  extends: TheTab,
  props
}
