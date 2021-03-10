import { BaseFormGroupArrayDraggable, BaseFormGroupArrayDraggableProps } from '@/components/new'
import BaseRuleAction from './BaseRuleAction'
import i18n from '@/utils/locale'

export const props = {
  ...BaseFormGroupArrayDraggableProps,

  buttonLabel: {
    type: String,
    default: i18n.t('Add Action')
  },
  // overload :childComponent
  childComponent: {
    type: Object,
    default: () => BaseRuleAction
  },
  // overload :defaultItem
  defaultItem: {
    type: Object,
    default: () => ({
      type: null,
      value: null
    })
  },
  // overload draggable handlers
  onAdd: {
    type: Function,
    default: (context, index, newComponent) => {
      const { doFocus = () => {} } = newComponent
      doFocus()
    }
  }
}

export default {
  name: 'base-rule-form-group-actions',
  extends: BaseFormGroupArrayDraggable,
  props
}
