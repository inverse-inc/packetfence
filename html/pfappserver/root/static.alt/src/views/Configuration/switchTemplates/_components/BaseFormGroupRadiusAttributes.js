import { BaseFormGroupArrayDraggable, BaseFormGroupArrayDraggableProps } from '@/components/new'
import BaseRadiusAttribute from './BaseRadiusAttribute'
import i18n from '@/utils/locale'

export const props = {
  ...BaseFormGroupArrayDraggableProps,

  buttonLabel: {
    type: String,
    default: i18n.t('Add RADIUS Attribute')
  },
  // overload :childComponent
  childComponent: {
    type: Object,
    default: () => BaseRadiusAttribute
  },
  // overload :defaultItem
  defaultItem: {
    type: Object,
    default: () => ({
      type: null,
      value: null
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
  name: 'base-form-group-radius-attributes',
  extends: BaseFormGroupArrayDraggable,
  props
}
