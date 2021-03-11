import { BaseFormGroupArrayDraggable, BaseFormGroupArrayDraggableProps } from '@/components/new'
import BaseRuleCondition from './BaseRuleCondition'
import i18n from '@/utils/locale'

export const props = {
  ...BaseFormGroupArrayDraggableProps,

  buttonLabel: {
    type: String,
    default: i18n.t('Add Condition')
  },
  // overload :childComponent
  childComponent: {
    type: Object,
    default: () => BaseRuleCondition
  },
  // overload :defaultItem
  defaultItem: {
    type: Object,
    default: () => ({
      attribute: null,
      operator: null,
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
  name: 'base-rule-form-group-conditions',
  extends: BaseFormGroupArrayDraggable,
  props
}
