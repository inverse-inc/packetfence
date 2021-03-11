import { BaseFormGroupArray, BaseFormGroupArrayProps } from '@/components/new'
import BaseTrigger from './BaseTrigger'
import i18n from '@/utils/locale'

export const props = {
  ...BaseFormGroupArrayProps,

  buttonLabel: {
    type: String,
    default: i18n.t('Add Trigger')
  },
  // overload :childComponent
  childComponent: {
    type: Object,
    default: () => BaseTrigger
  },
  // overload :defaultItem
  defaultItem: {
    type: Object,
    default: () => ({
      endpoint: {
        conditions: []
      },
      profiling: {
        conditions: []
      },
      usage: {},
      event: {}
    })
  }
}

export default {
  name: 'base-form-group-triggers',
  extends: BaseFormGroupArray,
  props
}
