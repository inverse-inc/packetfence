import { BaseFormGroupArray, BaseFormGroupArrayProps } from '@/components/new'
import BaseDeviceAttributesDiffThresholdOverride from './BaseDeviceAttributesDiffThresholdOverride'
import i18n from '@/utils/locale'

export const props = {
  ...BaseFormGroupArrayProps,

  buttonLabel: {
    type: String,
    default: i18n.t('Add Attribute')
  },
  // overload :childComponent
  childComponent: {
    type: Object,
    default: () => BaseDeviceAttributesDiffThresholdOverride
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
  name: 'base-form-group-device-attributes-diff-threshold-overrides',
  extends: BaseFormGroupArray,
  props
}
