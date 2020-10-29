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
  name: 'base-form-group-triggers',
  extends: BaseFormGroupArray,
  props
}
