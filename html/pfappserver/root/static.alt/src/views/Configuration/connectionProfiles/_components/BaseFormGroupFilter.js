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
  // overload draggable handlers
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
