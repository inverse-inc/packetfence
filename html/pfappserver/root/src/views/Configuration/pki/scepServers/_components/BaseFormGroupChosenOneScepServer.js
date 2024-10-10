import { BaseFormGroupChosenOne, BaseFormGroupChosenOneProps } from '@/components/new/'
import store from '@/store'
import StoreModule from '../../_store'

export const props = {
  ...BaseFormGroupChosenOneProps,

  // overload :options default
  options: {
    type: Promise,
    default: () => {
      if (!store.state.$_pkis)
        store.registerModule('$_pkis', StoreModule)
      return store.dispatch('$_pkis/allScepServers').then(scepServers => {
        return scepServers.map(scepServer => ({ text: scepServer.name, value: scepServer.id }))
      })
    }
  }
}

export default {
  name: 'base-form-group-chosen-one-scep-server',
  extends: BaseFormGroupChosenOne,
  props
}
