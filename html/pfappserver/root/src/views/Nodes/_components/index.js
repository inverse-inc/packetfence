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
import BaseFormGroupRolesOptional from './BaseFormGroupRolesOptional'
import BaseFormGroupStatus from './BaseFormGroupStatus'
import BaseFormGroupPersonSearchable from '@/views/Users/_components/BaseFormGroupPersonSearchable'

export {
  BaseFormButtonBar             as FormButtonBar,
  BaseInputChosenOne            as FormSecurityEvents,

  BaseFormGroupPersonSearchable as FormGroupPid,
  BaseFormGroupStatus           as FormGroupStatus,
  BaseFormGroupRolesOptional    as FormGroupRole,
  BaseFormGroupInputDateTime    as FormGroupUnregdate,
  BaseFormGroupInputNumber      as FormGroupTimeBalance,
  BaseFormGroupInputMultiplier  as FormGroupBandwidthBalance,
  BaseFormGroupSwitch           as FormGroupVoip,
  BaseFormGroupInput            as FormGroupBypassVlan,
  BaseFormGroupRolesOptional    as FormGroupBypassRole,
  BaseFormGroupTextarea         as FormGroupNotes,
  BaseFormGroupTextarea         as FormGroupBypassAcls,
  BaseFormGroupInput            as FormGroupComputername,

  BaseFormGroupInput            as FormGroupMac,

}
