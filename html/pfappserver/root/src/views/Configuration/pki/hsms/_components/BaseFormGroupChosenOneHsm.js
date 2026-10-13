import { BaseFormGroupChosenOne, BaseFormGroupChosenOneProps } from '@/components/new/'
import store from '@/store'
import i18n from '@/utils/locale'
import StoreModule from '../../_store'

export const props = {
  ...BaseFormGroupChosenOneProps,

  // overload :options default
  options: {
    type: Promise,
    default: () => {
      if (!store.state.$_pkis)
        store.registerModule('$_pkis', StoreModule)
      return store.dispatch('$_pkis/allHsms').then(hsms => {
        return [
          { text: i18n.t('None (key stored in the database)'), value: '0' },
          ...hsms.map(hsm => ({ text: hsm.name, value: hsm.id }))
        ]
      })
    }
  }
}

export default {
  name: 'base-form-group-chosen-one-hsm',
  extends: BaseFormGroupChosenOne,
  props
}
