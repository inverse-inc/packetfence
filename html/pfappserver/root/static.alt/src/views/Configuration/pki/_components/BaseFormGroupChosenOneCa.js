import { BaseFormGroupChosenOne, BaseFormGroupChosenOneProps } from '@/components/new/'
import store from '@/store'
import StoreModule from '../_store'

export const props = {
  ...BaseFormGroupChosenOneProps,

  // overload :options default
  options: {
    type: Promise,
    default: () => store.dispatch('$_pkis/allCas').then(cas => {
      return cas.map(ca => ({ value: ca.ID.toString(), text: ca.cn }))
    })
  }
}

const setup = () => {
  if (!store.state.$_pkis) {
    store.registerModule('$_pkis', StoreModule)
  }
}

export default {
  name: 'base-form-group-chosen-one-ca',
  extends: BaseFormGroupChosenOne,
  props,
  setup
}
