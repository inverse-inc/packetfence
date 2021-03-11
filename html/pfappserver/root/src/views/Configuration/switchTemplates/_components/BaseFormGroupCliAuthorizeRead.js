import { BaseFormGroupArray, BaseFormGroupArrayProps } from '@/components/new'
import BaseRadiusAttribute from './BaseRadiusAttribute'
import i18n from '@/utils/locale'

export const props = {
  ...BaseFormGroupArrayProps,

  buttonLabel: {
    type: String,
    default: i18n.t('Add RADIUS Attribute')
  },
  // overload :childComponent
  childComponent: {
    type: Object,
    default: () => BaseRadiusAttribute
  },
  // overload :defaultItem
  defaultItem: {
    type: Object,
    default: () => ({
      type: undefined,
      value: undefined
    })
  }
}

export default {
  name: 'base-form-group-cli-authorize-read',
  extends: BaseFormGroupArray,
  props
}
