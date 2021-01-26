import { BaseFormGroupArrayDraggable, BaseFormGroupArrayDraggableProps } from '@/components/new'
import {
  BaseInputChosenOne
} from '@/components/new/'
import i18n from '@/utils/locale'

export const props = {
  ...BaseFormGroupArrayDraggableProps,

  buttonLabel: {
    type: String,
    default: i18n.t('Add Provisioner')
  },
  // overload :childComponent
  childComponent: {
    type: Object,
    default: () => BaseInputChosenOne
  },
  // overload :defaultItem
  defaultItem: {
    type: String
  },
  // overload draggable handlers
  onAdd: {
    type: Function,
    default: (context, index, newComponent) => {
      const { doFocus = () => {} } = newComponent
      doFocus()
    }
  },
  striped: {
    type: Boolean,
    default: true
  }
}

export default {
  name: 'base-form-group-provisioners',
  extends: BaseFormGroupArrayDraggable,
  props
}
