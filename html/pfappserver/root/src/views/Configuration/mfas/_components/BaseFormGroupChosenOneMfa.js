import { BaseFormGroupChosenOne, BaseFormGroupChosenOneProps } from '@/components/new/'
import store from '@/store'
import StoreModule from '../_store'

export const props = {
  ...BaseFormGroupChosenOneProps,

  // overload :options default
  options: {
    type: Promise,
    default: () => {
      if (!store.state.$_mfas)
        store.registerModule('$_mfas', StoreModule)
      return store.dispatch('$_mfas/all').then(mfas => {
        return mfas.map(mfa => ({ text: `${mfa.id}`, value: mfa.id }))
      })
    }
  }
}

export default {
  name: 'base-form-group-chosen-one-mfa',
  extends: BaseFormGroupChosenOne,
  props
}
