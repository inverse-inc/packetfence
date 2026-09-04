import { BaseFormGroupArray, BaseFormGroupArrayProps } from '@/components/new'
import BaseInterface from './BaseInterface'
import i18n from '@/utils/locale'

export const props = {
  ...BaseFormGroupArrayProps,

  buttonLabel: {
    type: String,
    default: i18n.t('Add VLAN Interface')
  },
  // overload :childComponent
  childComponent: {
    type: Object,
    default: () => BaseInterface
  },
  // overload :defaultItem
  defaultItem: {
    type: Object,
    default: () => ({
      parent: null,
      vlan: null,
      cidr: null
    })
  }
}

export default {
  name: 'base-form-group-interfaces',
  extends: BaseFormGroupArray,
  props
}
