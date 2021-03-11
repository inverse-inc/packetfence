import { BaseFormGroupArray, BaseFormGroupArrayProps } from '@/components/new'
import BaseAction from './BaseAction'
import i18n from '@/utils/locale'

export const props = {
  ...BaseFormGroupArrayProps,

  buttonLabel: {
    type: String,
    default: i18n.t('Add Action')
  },
  // overload :childComponent
  childComponent: {
    type: Object,
    default: () => BaseAction
  },
  // overload :defaultItem
  defaultItem: {
    type: Object,
    default: () => ({
      type: undefined,
      value: undefined
    })
  },
  // overload draggable handlers
  onAdd: {
    type: Function,
    default: (context, index, newComponent) => {
      const { doFocus = () => {} } = newComponent
      doFocus()
    }
  }
}

export default {
  name: 'base-form-group-actions',
  extends: BaseFormGroupArray,
  props
}
