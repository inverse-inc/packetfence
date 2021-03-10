import { BaseFormGroupArrayDraggable, BaseFormGroupArrayDraggableProps } from '@/components/new'
import BaseFilter from './BaseFilter'
import i18n from '@/utils/locale'

export const props = {
  ...BaseFormGroupArrayDraggableProps,

  buttonLabel: {
    type: String,
    default: i18n.t('Add Filter')
  },
  // overload :childComponent
  childComponent: {
    type: Object,
    default: () => BaseFilter
  },
  // overload :defaultItem
  defaultItem: {
    type: Object,
    default: () => ({
      type: undefined,
      match: undefined
    })
  },
  striped: {
    type: Boolean,
    default: true
  }
}

export default {
  name: 'base-form-group-filter',
  extends: BaseFormGroupArrayDraggable,
  props
}
