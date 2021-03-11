import { BaseInputChosenOne, BaseInputChosenOneProps } from '@/components/new/'
import store from '@/store'
import StoreModule from '../_store'

export const props = {
  ...BaseInputChosenOneProps,

  // overload :options default
  options: {
    type: Promise,
    default: () => {
      if (!store.state.$_roles)
        store.registerModule('$_roles', StoreModule)
      return store.dispatch('$_roles/all').then(roles => roles.map(({ id }) => ({ text: id, value: id })))
    }
  }
}

export default {
  name: 'base-input-chosen-one-role',
  extends: BaseInputChosenOne,
  props
}
