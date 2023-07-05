import {BaseViewCollectionItem} from '../../_components/new/'
import {
  BaseFormButtonBar,
  BaseFormGroupChosenOne,
  BaseFormGroupInput,
  BaseFormGroupSwitch,
  BaseFormGroupTextarea
} from '@/components/new/'
import TheForm from './TheForm'
import TheView from './TheView'

export {
  BaseFormButtonBar                   as FormButtonBar,

  BaseFormGroupInput                  as FormGroupIdentifier,
  BaseFormGroupInput                  as FormGroupNotes,
  BaseFormGroupInput                  as FormGroupMaxNodesPerPid,
  BaseFormGroupChosenOne              as FormGroupParentIdentifier,
  BaseFormGroupSwitch                 as FormGroupIncludeParentAcls,
  BaseFormGroupSwitch                 as FormGroupFingerbankDynamicAccessList,
  BaseFormGroupTextarea               as FormGroupAcls,
  BaseFormGroupSwitch                 as FormGroupInheritVlan,
  BaseFormGroupSwitch                 as FormGroupInheritRole,
  BaseFormGroupSwitch                 as FormGroupInheritWebAuthUrl,

  BaseViewCollectionItem              as BaseView,
  TheForm,
  TheView
}
