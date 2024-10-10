import { BaseFormGroupArrayDraggableProps } from '@/components/new'
import BaseRuleCondition from './BaseRuleCondition'
import i18n from '@/utils/locale'
import BaseFormGroupArrayDraggableStaticButtons
  from '@/components/new/BaseFormGroupArrayDraggableStaticButtons';
import LdapRuleCondition from '@/views/Configuration/sources/_components/LdapRuleCondition';

export const props = {
  ...BaseFormGroupArrayDraggableProps,

  buttonLabel: {
    type: String,
    default: i18n.t('Add Condition')
  },
  // overload :childComponent
  childComponent: {
    type: Object,
    default: () => BaseRuleCondition
  },
  // overload :defaultItem
  defaultItem: {
    type: Object,
    default: () => ({
      attribute: null,
      operator: null,
      value: null
    })
  },
  // overload draggable handlers
  onAdd: {
    type: Function,
    default: (context, index, newComponent) => {
      const { doFocus = () => {} } = newComponent
      doFocus()
    }
  },
  buttons: {
    type: Array,
    default: () => {return [{
      label: i18n.t('Add Packetfence Condition'),
      component: "base-rule-condition",
      type: "pf"
    },{
      label: i18n.t('Add LDAP Condition'),
      component: "ldap-rule-condition",
      type: "ldap"
    }]}
  }
}

const components = {
  BaseRuleCondition,
  LdapRuleCondition
}

export default {
  name: 'base-rule-form-group-conditions',
  extends: BaseFormGroupArrayDraggableStaticButtons,
  props,
  components
}
