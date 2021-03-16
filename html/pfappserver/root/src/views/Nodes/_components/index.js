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
import BaseFormGroupPid from './BaseFormGroupPid'
import BaseFormGroupRolesWithNull from './BaseFormGroupRolesWithNull'
import BaseFormGroupStatus from './BaseFormGroupStatus'

export {
  BaseFormButtonBar             as FormButtonBar,
  BaseInputChosenOne            as FormSecurityEvents,

  BaseFormGroupPid              as FormGroupPid,
  BaseFormGroupStatus           as FormGroupStatus,
  BaseFormGroupRolesWithNull    as FormGroupRole,
  BaseFormGroupInputDateTime    as FormGroupUnregdate,
  BaseFormGroupInputNumber      as FormGroupTimeBalance,
  BaseFormGroupInputMultiplier  as FormGroupBandwidthBalance,
  BaseFormGroupToggleNoYes      as FormGroupVoip,
  BaseFormGroupInput            as FormGroupBypassVlan,
  BaseFormGroupRolesWithNull    as FormGroupBypassRole,
  BaseFormGroupTextarea         as FormGroupNotes
}
