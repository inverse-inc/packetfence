import { BaseFormGroupArrayDraggable, BaseFormGroupArrayDraggableProps } from '@/components/new'
import BasePersonMapping from './BasePersonMapping'
import i18n from '@/utils/locale'

export const props = {
  ...BaseFormGroupArrayDraggableProps,

  buttonLabel: {
    type: String,
    default: i18n.t('Add Mapping')
  },
  // overload :draggableComponent
  draggableComponent: {
    type: Object,
    default: () => BasePersonMapping
  },
  // overload :defaultItem
  defaultItem: {
    type: Object,
    default: () => ({
      person_field: undefined,
      openid_field: undefined
    })
  }
}

export default {
  name: 'base-form-group-person-mappings',
  extends: BaseFormGroupArrayDraggable,
  props
}
