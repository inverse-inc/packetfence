import { BaseFormGroupChosenOne, BaseFormGroupChosenOneProps } from '@/components/new/'
export const props = {
  ...BaseFormGroupChosenOneProps,

  // overload :options default
  options: {
    type: Array,
    default: () => ([
      { value: 'NONE', text: 'None' },
      { value: 'WPA-Enterprise', text: 'WPA Enterprise' },
      { value: 'WPA2', text: 'WPA2' },
      { value: 'EAP-PEAP', text: 'EAP PEAP' },
      { value: 'EAP-TTLS', text: 'EAP TTLS' },
      { value: 'EAP_SIM', text: 'EAP SIM' },
      { value: 'EAP-AKA', text: 'EAP AKA' }
    ])
  }
}

export default {
  name: 'base-form-group-security-protocol1x',
  extends: BaseFormGroupChosenOne,
  props
}
