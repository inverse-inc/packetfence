import { BaseFormGroupArray, BaseFormGroupArrayProps } from '@/components/new'
import BaseDns from './BaseDns'
import i18n from '@/utils/locale'

export const props = {
  ...BaseFormGroupArrayProps,

  buttonLabel: {
    type: String,
    default: i18n.t('Add Domain')
  },
  // overload :showIndex
  showIndex: false,

  // overload :childComponent
  childComponent: {
    type: Object,
    default: () => BaseDns
  },

  // overload :defaultItem
  defaultItem: {
    type: Object,
    default: () => ({
      domain: null,
      ip: null,
      port: null,
      pfconnector_port: null
    })
  }
}

export default {
  name: 'base-form-group-domains',
  extends: BaseFormGroupArray,
  props
}