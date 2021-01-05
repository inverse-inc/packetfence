import { BaseFormGroupArrayDraggable, BaseFormGroupArrayDraggableProps } from '@/components/new'
import BaseAnswer from './BaseAnswer'
import i18n from '@/utils/locale'

export const props = {
  ...BaseFormGroupArrayDraggableProps,

  buttonLabel: {
    type: String,
    default: i18n.t('Add Answer')
  },
  // overload :childComponent
  childComponent: {
    type: Object,
    default: () => BaseAnswer
  },
  // overload :defaultItem
  defaultItem: {
    type: Object,
    default: () => ({
      prefix: undefined,
      type: undefined,
      value: undefined
    })
  }
}

export default {
  name: 'base-form-group-answers',
  extends: BaseFormGroupArrayDraggable,
  props
}
