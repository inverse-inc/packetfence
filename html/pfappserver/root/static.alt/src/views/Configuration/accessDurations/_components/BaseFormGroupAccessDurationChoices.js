import { BaseFormGroupArray, BaseFormGroupArrayProps } from '@/components/new'
import BaseAccessDuration from './BaseAccessDuration'
import i18n from '@/utils/locale'

export const props = {
  ...BaseFormGroupArrayProps,

  buttonLabel: {
    type: String,
    default: i18n.t('Add Access Duration')
  },
  // overload :childComponent
  childComponent: {
    type: Object,
    default: () => BaseAccessDuration
  },
  // overload :defaultItem
  defaultItem: {
    type: Object,
    default: () => ({
      interval: null,
      unit: null,
      base: null,
      extendedInterval: null,
      extendedUnit: null
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
  name: 'base-form-group-access-duration-choices',
  extends: BaseFormGroupArray,
  props
}
