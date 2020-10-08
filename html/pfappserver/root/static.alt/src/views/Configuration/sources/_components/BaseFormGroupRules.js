import { BaseFormGroupArrayDraggable, BaseFormGroupArrayDraggableProps } from '@/components/new'
import BaseRule from './BaseRule'

export const props = {
  ...BaseFormGroupArrayDraggableProps,

  // overload :draggableComponent
  draggableComponent: {
    type: Object,
    default: () => BaseRule
  },
  // overload :defaultItem
  defaultItem: {
    type: Object,
    default: () => ({
      actions: [],
      conditions: [],
      description: null,
      id: null,
      match: 'all',
      status: 'enabled'
    })
  },
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
  name: 'base-form-group-rules',
  extends: BaseFormGroupArrayDraggable,
  props
}
