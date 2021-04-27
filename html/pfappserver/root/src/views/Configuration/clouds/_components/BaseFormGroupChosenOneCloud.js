import { BaseFormGroupChosenOne, BaseFormGroupChosenOneProps } from '@/components/new/'
import store from '@/store'
import StoreModule from '../_store'

export const props = {
  ...BaseFormGroupChosenOneProps,

  // overload :options default
  options: {
    type: Promise,
    default: () => store.dispatch('$_clouds/all').then(cloud => {
      return cloud.map(cloud => ({ value: cloud.id.toString(), text: cloud.id }))
    })
  }
}

const setup = () => {
  if (!store.state.$_clouds) {
    store.registerModule('$_clouds', StoreModule)
  }
}

export default {
  name: 'base-form-group-chosen-one-cloud',
  extends: BaseFormGroupChosenOne,
  props,
  setup
}
