import {
  BaseFormGroupArray, BaseFormGroupArrayProps,
  BaseInput, BaseInputProps
} from '@/components/new'
import i18n from '@/utils/locale'

export const props = {
  ...BaseFormGroupArrayProps,
  ...BaseInputProps,

  buttonLabel: {
    type: String,
    default: i18n.t('Add VLAN')
  },
  // overload :childComponent
  childComponent: {
    type: Object,
    default: () => BaseInput
  },
  // overload :defaultItem
  defaultItem: {
    type: Object,
    default: () => (null)
  }
}

export default {
  name: 'base-form-group-allowed-node-bypass-vlans',
  extends: BaseFormGroupArray,
  props
}