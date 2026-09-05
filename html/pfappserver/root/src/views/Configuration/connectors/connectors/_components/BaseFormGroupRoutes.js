import { BaseFormGroupArray, BaseFormGroupArrayProps } from '@/components/new'
import BaseRoute from './BaseRoute'
import i18n from '@/utils/locale'

export const props = {
  ...BaseFormGroupArrayProps,

  buttonLabel: {
    type: String,
    default: i18n.t('Add Static Route')
  },
  // overload :childComponent
  childComponent: {
    type: Object,
    default: () => BaseRoute
  },
  // overload :defaultItem
  defaultItem: {
    type: Object,
    default: () => ({
      destination: null,
      gateway: null,
      interface: null
    })
  }
}

export default {
  name: 'base-form-group-routes',
  extends: BaseFormGroupArray,
  props
}
