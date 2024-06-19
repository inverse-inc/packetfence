import { provide } from '@vue/composition-api'
import { BaseFormGroupArrayDraggable, BaseFormGroupArrayDraggableProps } from '@/components/new'
import BaseRuleAction from './BaseRuleAction'
import i18n from '@/utils/locale'
import { regexRuleActions } from '../config'

export const props = {
  ...BaseFormGroupArrayDraggableProps,

  buttonLabel: {
    type: String,
    default: i18n.t('Add Action')
  },
  // overload :childComponent
  childComponent: {
    type: Object,
    default: () => BaseRuleAction
  },
  // overload :defaultItem
  defaultItem: {
    type: Object,
    default: () => ({
      api_method: null,
      api_parameters: null
    })
  }
}

const setup = () => {
  const actions = Object.values(regexRuleActions)
  provide('actions', actions)
}

export default {
  name: 'base-rule-form-group-actions',
  extends: BaseFormGroupArrayDraggable,
  props,
  setup
}
