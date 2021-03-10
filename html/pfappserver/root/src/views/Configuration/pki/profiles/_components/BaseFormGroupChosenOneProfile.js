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
      return store.dispatch('$_pkis/allProfiles').then(profiles => {
        return profiles.map(profile => ({ text: `${profile.ca_name} - ${profile.name}`, value: profile.ID }))
      })
    }
  }
}

export default {
  name: 'base-form-group-chosen-one-profile',
  extends: BaseFormGroupChosenOne,
  props
}
