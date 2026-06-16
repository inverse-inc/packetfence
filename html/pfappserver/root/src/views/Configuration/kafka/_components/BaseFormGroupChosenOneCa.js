import { BaseFormGroupChosenOne, BaseFormGroupChosenOneProps } from '@/components/new/'
import store from '@/store'
import PkiStoreModule from '../../pki/_store'

export const props = {
  ...BaseFormGroupChosenOneProps,

  // overload :options default with the list of pfpki Certificate Authorities
  options: {
    type: Promise,
    default: () => {
      if (!store.state.$_pkis)
        store.registerModule('$_pkis', PkiStoreModule)
      return store.dispatch('$_pkis/allCas').then(cas => {
        return cas.map(ca => ({ text: ca.cn, value: `${ca.id}` }))
      })
    }
  }
}

export default {
  name: 'base-form-group-chosen-one-ca',
  extends: BaseFormGroupChosenOne,
  props
}
