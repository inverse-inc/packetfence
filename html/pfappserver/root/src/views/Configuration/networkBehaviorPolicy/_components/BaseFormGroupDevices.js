import {
  BaseFormGroupChosenMultipleSearchable,
  BaseFormGroupChosenMultipleSearchableProps
} from '@/components/new/'
import {
  commonDevices
} from '../config'

const props = {
  ...BaseFormGroupChosenMultipleSearchableProps,

  options: {
    type: Array,
    default: () => Object.keys(commonDevices).map(key => ({ text: commonDevices[key], value: key.toString() }))
  }
}

// @vue/component
export default {
  name: 'base-form-group-devices',
  extends: BaseFormGroupChosenMultipleSearchable,
  props
}
