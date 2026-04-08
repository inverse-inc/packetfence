import {BaseViewCollectionItem} from '../../_components/new/'
import {
  BaseFormButtonBar,
  BaseFormGroupInput,
  BaseFormGroupSwitch,
  BaseFormGroupTextarea
} from '@/components/new/'
import BaseFormGroupRolesSearchable from './BaseFormGroupRolesSearchable'
import TheForm from './TheForm'
import TheView from './TheView'

export {
  BaseFormButtonBar                   as FormButtonBar,

  BaseFormGroupInput                  as FormGroupIdentifier,
  BaseFormGroupInput                  as FormGroupNotes,
  BaseFormGroupInput                  as FormGroupMaxNodesPerPid,
  BaseFormGroupRolesSearchable        as FormGroupParentIdentifier,
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
