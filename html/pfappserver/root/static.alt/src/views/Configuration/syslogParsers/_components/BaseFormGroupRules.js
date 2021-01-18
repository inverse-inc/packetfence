import { BaseFormGroupArrayDraggable, BaseFormGroupArrayDraggableProps } from '@/components/new'
import BaseRule from './BaseRule'
import i18n from '@/utils/locale'

export const props = {
  ...BaseFormGroupArrayDraggableProps,

  buttonLabel: {
    type: String,
    default: i18n.t('Add Rule')
  },
  // overload :childComponent
  childComponent: {
    type: Object,
    default: () => BaseRule
  },
  // overload :defaultItem
  defaultItem: {
    type: Object,
    default: () => ({
      name: null,
      regex: null,
      actions: [],
      last_if_match: 'disabled',
      ip_mac_translation: 'enabled'
    })
  },
  // overload draggable handlers
  onAdd: {
    type: Function,
    default: (context, index, newComponent) => {
      const { doExpand = () => {} } = newComponent
      doExpand()
    }
  },
  onCopy: {
    type: Function,
    default: (context, fromIndex, toIndex, fromComponent, toComponent) => {
      const { isCollapse } = fromComponent
      if (!isCollapse) {
        const { doExpand = () => {} } = toComponent
        doExpand()
      }
    }
  },
  striped: {
    type: Boolean,
    default: true
  }
}

export default {
  name: 'base-form-group-rules',
  extends: BaseFormGroupArrayDraggable,
  props
}
