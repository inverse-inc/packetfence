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
  }
}

export default {
  name: 'base-form-group-answers',
  extends: BaseFormGroupArrayDraggable,
  props
}
