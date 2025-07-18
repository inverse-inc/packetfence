import { BaseViewCollectionItem } from '../../_components/new/'
import {
  BaseFormButtonBar,
  BaseFormGroupChosenMultiple,
  BaseFormGroupInput,
  BaseFormGroupInputDate,
  BaseFormGroupToggleDisabledEnabled,
} from '@/components/new/'
import BaseFormGroupAclAllowedActions from './BaseFormGroupAclAllowedActions'
import BaseFormGroupAllowedNodeBypassVlans from './BaseFormGroupAllowedNodeBypassVlans'
import TheForm from './TheForm'
import TheView from './TheView'

export {
  BaseViewCollectionItem              as BaseView,
  BaseFormButtonBar                   as FormButtonBar,

  BaseFormGroupInput                  as FormGroupIdentifier,
  BaseFormGroupInput                  as FormGroupDescription,
  BaseFormGroupChosenMultiple         as FormGroupActions,
  BaseFormGroupChosenMultiple         as FormGroupAllowedAccessLevels,
  BaseFormGroupChosenMultiple         as FormGroupAllowedRoles,
  BaseFormGroupInput                  as FormGroupAllowedAccessDurations,
  BaseFormGroupInputDate              as FormGroupAllowedUnregDate,
  BaseFormGroupAclAllowedActions      as FormGroupAllowedActions,
  BaseFormGroupChosenMultiple         as FormGroupAllowedNodeRoles,
  BaseFormGroupChosenMultiple         as FormGroupAllowedNodeBypassRoles,
  BaseFormGroupAllowedNodeBypassVlans as FormGroupAllowedNodeBypassVlans,
  BaseFormGroupChosenMultiple         as FormGroupDisallowedRoles,
  BaseFormGroupChosenMultiple         as FormGroupDisallowedNodeBypassRoles,
  BaseFormGroupChosenMultiple         as FormGroupDisallowedNodeRoles,
  BaseFormGroupToggleDisabledEnabled  as FormGroupDisableBypassVlan,
  TheForm,
  TheView
}
