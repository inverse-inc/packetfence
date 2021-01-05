import { BaseInputArray, BaseInputArrayProps } from '@/components/new'
import BaseTriggerProfilingCondition from './BaseTriggerProfilingCondition'
import i18n from '@/utils/locale'

export const props = {
  ...BaseInputArrayProps,

  buttonLabel: {
    type: String,
    default: i18n.t('Add Condition')
  },
  // overload :childComponent
  childComponent: {
    type: Object,
    default: () => BaseTriggerProfilingCondition
  },
  // overload :defaultItem
  defaultItem: {
    type: Object,
    default: () => ({
      type: null,
      value: null
    })
  }
}

export default {
  name: 'base-trigger-profiling-conditions',
  extends: BaseInputArray,
  props
}
