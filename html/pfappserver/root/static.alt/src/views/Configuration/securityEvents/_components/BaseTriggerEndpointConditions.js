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
  },
  // overload handlers
  onAdd: {
    type: Function,
    default: (context, index, newComponent) => {
      const { onExpand = () => {} } = newComponent
      onExpand()
    }
  },
  onCopy: {
    type: Function,
    default: (context, fromIndex, toIndex, fromComponent, toComponent) => {
      const { isCollapse } = fromComponent
      if (!isCollapse) {
        const { onExpand = () => {} } = toComponent
        onExpand()
      }
    }
  }
}

export default {
  name: 'base-trigger-endpoint-conditions',
  extends: BaseInputArray,
  props
}
