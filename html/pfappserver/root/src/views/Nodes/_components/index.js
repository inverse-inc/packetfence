import {
  BaseInputChosenOne,
  BaseFormButtonBar,
  BaseFormGroupInput,
  BaseFormGroupInputDateTime,
  BaseFormGroupInputMultiplier,
  BaseFormGroupInputNumber,
  BaseFormGroupTextarea,
  BaseFormGroupToggleNoYes
} from '@/components/new/'
import BaseFormGroupRolesWithNull from './BaseFormGroupRolesWithNull'
import BaseFormGroupStatus from './BaseFormGroupStatus'
import BaseFormGroupPersonSearchable from '@/views/Users/_components/BaseFormGroupPersonSearchable'

export {
  BaseFormButtonBar             as FormButtonBar,
  BaseInputChosenOne            as FormSecurityEvents,

  BaseFormGroupPersonSearchable as FormGroupPid,
  BaseFormGroupStatus           as FormGroupStatus,
  BaseFormGroupRolesWithNull    as FormGroupRole,
  BaseFormGroupInputDateTime    as FormGroupUnregdate,
  BaseFormGroupInputNumber      as FormGroupTimeBalance,
  BaseFormGroupInputMultiplier  as FormGroupBandwidthBalance,
  BaseFormGroupToggleNoYes      as FormGroupVoip,
  BaseFormGroupInput            as FormGroupBypassVlan,
  BaseFormGroupRolesWithNull    as FormGroupBypassRole,
  BaseFormGroupTextarea         as FormGroupNotes,
  
  BaseFormGroupInput            as FormGroupMac,
  
}
