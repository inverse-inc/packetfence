import { BaseInputArray, BaseInputArrayProps } from '@/components/new'
import BaseTriggerEndpointCondition from './BaseTriggerEndpointCondition'
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
    default: () => BaseTriggerEndpointCondition
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
  name: 'base-trigger-endpoint-conditions',
  extends: BaseInputArray,
  props
}
