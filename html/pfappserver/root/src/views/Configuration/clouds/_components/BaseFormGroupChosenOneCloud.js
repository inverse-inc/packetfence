import { BaseFormGroupChosenOne, BaseFormGroupChosenOneProps } from '@/components/new/'
import store from '@/store'
import StoreModule from '../_store'

export const props = {
  ...BaseFormGroupChosenOneProps,

  // overload :options default
  options: {
    type: Promise,
    default: () => {
      if (!store.state.$_clouds)
        store.registerModule('$_clouds', StoreModule)
      return store.dispatch('$_clouds/all').then(clouds => {
        return clouds.map(cloud => ({ text: `${cloud.id}`, value: cloud.id }))
      })
    }
  }
}

export default {
  name: 'base-form-group-chosen-one-cloud',
  extends: BaseFormGroupChosenOne,
  props
}
