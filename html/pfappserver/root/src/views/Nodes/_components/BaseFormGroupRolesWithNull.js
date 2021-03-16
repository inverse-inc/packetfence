import { BaseFormGroupChosenOne, BaseFormGroupChosenOneProps } from '@/components/new/'
import store from '@/store'
import i18n from '@/utils/locale'

export const props = {
  ...BaseFormGroupChosenOneProps,

  // overload :options default
  options: {
    type: Promise,
    default: () => {
      return store.dispatch('session/getAllowedNodeRoles')
        .then(roles => ([
          { value: null, text: i18n.t('No Role') }, // prepend a null value to roles
          ...roles.map(role => ({ value: role.category_id, text: `${role.name} - ${role.notes}` }))
        ]))
    }
  }
}

export default {
  name: 'base-form-group-roles-with-null',
  extends: BaseFormGroupChosenOne,
  props
}
