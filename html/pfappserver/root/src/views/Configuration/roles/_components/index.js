import { BaseViewCollectionItem } from '../../_components/new/'
import {
  BaseFormButtonBar,
  BaseFormGroupChosenOne,
  BaseFormGroupInput,
  BaseFormGroupTextarea,
  BaseFormGroupToggleDisabledEnabled
} from '@/components/new/'
import TheForm from './TheForm'
import TheView from './TheView'

export {
  BaseFormButtonBar                   as FormButtonBar,

  BaseFormGroupInput                  as FormGroupIdentifier,
  BaseFormGroupInput                  as FormGroupNotes,
  BaseFormGroupInput                  as FormGroupMaxNodesPerPid,
  BaseFormGroupChosenOne              as FormGroupParentIdentifier,
  BaseFormGroupToggleDisabledEnabled  as FormGroupIncludeParentAcls,
  BaseFormGroupToggleDisabledEnabled  as FormGroupFingerbankDynamicAccessList,
  BaseFormGroupTextarea               as FormGroupAcls,
  BaseFormGroupToggleDisabledEnabled  as FormGroupInheritVlan,
  BaseFormGroupToggleDisabledEnabled  as FormGroupInheritRole,
  BaseFormGroupToggleDisabledEnabled  as FormGroupInheritWebAuth,

  BaseViewCollectionItem              as BaseView,
  TheForm,
  TheView
}
