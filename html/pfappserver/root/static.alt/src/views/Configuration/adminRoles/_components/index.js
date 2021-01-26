import { BaseViewCollectionItem } from '../../_components/new/'
import {
  BaseFormButtonBar,
  BaseFormGroupChosenMultiple,
  BaseFormGroupInput,
  BaseFormGroupInputDate
} from '@/components/new/'
import BaseFormGroupAclAllowedActions from './BaseFormGroupAclAllowedActions'
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

  TheForm,
  TheView
}
