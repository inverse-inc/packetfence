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
  }
}

export default {
  name: 'base-form-group-device-attributes-diff-threshold-overrides',
  extends: BaseFormGroupArray,
  props
}
