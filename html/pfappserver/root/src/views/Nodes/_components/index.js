import {
  BaseInputChosenOne,
  BaseFormButtonBar,
  BaseFormGroupInput,
  BaseFormGroupInputDateTime,
  BaseFormGroupInputMultiplier,
  BaseFormGroupInputNumber,
  BaseFormGroupTextarea,
  BaseFormGroupSwitch,
} from '@/components/new/'
import BaseFormGroupBypassRoles from './BaseFormGroupBypassRoles'
import BaseFormGroupBypassVlan from './BaseFormGroupBypassVlan'
import BaseFormGroupRoles from './BaseFormGroupRoles'
import BaseFormGroupStatus from './BaseFormGroupStatus'
import BaseFormGroupPersonSearchable from '@/views/Users/_components/BaseFormGroupPersonSearchable'

export {
  BaseFormButtonBar             as FormButtonBar,
  BaseInputChosenOne            as FormSecurityEvents,

  BaseFormGroupPersonSearchable as FormGroupPid,
  BaseFormGroupStatus           as FormGroupStatus,
  BaseFormGroupRoles            as FormGroupRole,
  BaseFormGroupInputDateTime    as FormGroupUnregdate,
  BaseFormGroupInputNumber      as FormGroupTimeBalance,
  BaseFormGroupInputMultiplier  as FormGroupBandwidthBalance,
  BaseFormGroupSwitch           as FormGroupVoip,
  BaseFormGroupBypassVlan       as FormGroupBypassVlan,
  BaseFormGroupBypassRoles      as FormGroupBypassRole,
  BaseFormGroupTextarea         as FormGroupNotes,
  BaseFormGroupTextarea         as FormGroupBypassAcls,
  BaseFormGroupInput            as FormGroupComputername,

  BaseFormGroupInput            as FormGroupMac,

}
