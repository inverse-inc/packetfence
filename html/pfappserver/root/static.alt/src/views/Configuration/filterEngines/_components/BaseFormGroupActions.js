import { BaseFormGroupArray, BaseFormGroupArrayProps } from '@/components/new'
import BaseAction from './BaseAction'
import i18n from '@/utils/locale'

export const props = {
  ...BaseFormGroupArrayProps,

  buttonLabel: {
    type: String,
    default: i18n.t('Add Action')
  },
  // overload :childComponent
  childComponent: {
    type: Object,
    default: () => BaseAction
  },
  // overload :defaultItem
  defaultItem: {
    type: Object,
    default: () => ({
      api_method: undefined,
      api_parameters: undefined
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
  name: 'base-form-group-actions',
  extends: BaseFormGroupArray,
  props
}

