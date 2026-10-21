import { BaseFormGroupChosenMultiple, BaseFormGroupChosenMultipleProps } from '@/components/new/'
import store from '@/store'
import StoreModule from '../../_store'

export const props = {
  ...BaseFormGroupChosenMultipleProps,

  // overload :options default
  options: {
    type: Promise,
    default: () => {
      if (!store.state.$_connectors)
        store.registerModule('$_connectors', StoreModule)
      return store.dispatch('$_connectors/allDomains').then(domains => {
        return domains.map(domain => ({ text: `${domain.id}`, value: domain.id }))
      })
    }
  }
}

export default {
  name: 'base-form-group-domains',
  extends: BaseFormGroupChosenMultiple,
  props
}
