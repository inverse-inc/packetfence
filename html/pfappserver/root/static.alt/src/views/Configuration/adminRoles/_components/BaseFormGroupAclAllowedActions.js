import { BaseFormGroupChosenMultiple, BaseFormGroupChosenMultipleProps } from '@/components/new/'
import store from '@/store'
import { pfActions } from '@/globals/pfActions'

export const props = {
  ...BaseFormGroupChosenMultipleProps,

  // overload :options default
  options: {
    type: Promise,
    default: () => store.dispatch('session/getAllowedUserActions').then(actions => actions.map(_action => {
      const { action } = _action
      const { [action]: { text = action } = {} } = pfActions
      return { text, value: action }
    }))
  }
}

export default {
  name: 'base-form-group-acl-allowed-actions',
  extends: BaseFormGroupChosenMultiple,
  props
}
