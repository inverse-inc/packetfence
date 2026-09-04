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
      cidr: null,
      dhcp: 'disabled',
      dns_server: 'disabled',
      dhcp_start: null,
      dhcp_end: null,
      dhcp_default_lease_time: 300,
      dhcp_max_lease_time: 600,
      dns: null,
      gateway: null,
      domain_name: null
    })
  }
}

export default {
  name: 'base-form-group-interfaces',
  extends: BaseFormGroupArray,
  props
}
