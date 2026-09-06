import { BaseFormGroupArray, BaseFormGroupArrayProps } from '@/components/new'
import BaseDnsServer from './BaseDnsServer'
import i18n from '@/utils/locale'

export const props = {
  ...BaseFormGroupArrayProps,

  buttonLabel: {
    type: String,
    default: i18n.t('Add DNS Server')
  },
  // overload :childComponent
  childComponent: {
    type: Object,
    default: () => BaseDnsServer
  },
  // overload :defaultItem
  defaultItem: {
    type: Object,
    default: () => ({
      ip: null,
      port: 53,
      tunnel_port: null,
      domains: []
    })
  }
}

export default {
  name: 'base-form-group-dns-servers',
  extends: BaseFormGroupArray,
  props
}
