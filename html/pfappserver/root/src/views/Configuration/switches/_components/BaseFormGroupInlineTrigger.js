import { BaseFormGroupArrayDraggable, BaseFormGroupArrayDraggableProps } from '@/components/new'
import BaseInlineTriggerCondition from './BaseInlineTriggerCondition'
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
    default: () => BaseInlineTriggerCondition
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
  name: 'base-form-group-inline-trigger',
  extends: BaseFormGroupArrayDraggable,
  props
}

