import { BaseFormGroupChosenOne, BaseFormGroupChosenOneProps } from '@/components/new/'
import store from '@/store'
import i18n from '@/utils/locale'

const ALL_VLANS = [
  { value: null, text: i18n.t('No VLAN') },
  ...Array.from({ length: 4096 }, (_, i) => ({ value: String(i + 1), text: String(i + 1) }))
]

export const props = {
  ...BaseFormGroupChosenOneProps,

  // overload :options default
  options: {
    type: Promise,
    default: () => {
      return store.dispatch('session/getAllowedNodeBypassVlans')
        .then(() => {
          const allowed = store.getters['session/allowedNodeBypassVlansList']
          if (allowed.length > 0) {
            return [{ value: null, text: i18n.t('No VLAN') }, ...allowed]
          }
          return ALL_VLANS
        })
    }
  }
}

export default {
  name: 'base-form-group-bypass-vlan',
  extends: BaseFormGroupChosenOne,
  props
}
