import {
  BaseInputChosenOne,
  BaseFormButtonBar,
  BaseFormGroupChosenOne,
  BaseFormGroupInput,
  BaseFormGroupInputDateTime,
  BaseFormGroupInputMultiplier,
  BaseFormGroupInputNumber,
  BaseFormGroupTextarea,
  BaseFormGroupToggleNoYes,
} from '@/components/new/'
import BaseFormGroupPid from './BaseFormGroupPid'

export {
  BaseFormButtonBar             as FormButtonBar,
  BaseInputChosenOne            as FormSecurityEvents,

  BaseFormGroupPid              as FormGroupPid,
  BaseFormGroupChosenOne        as FormGroupStatus,
  BaseFormGroupChosenOne        as FormGroupRole,
  BaseFormGroupInputDateTime    as FormGroupUnregdate,
  BaseFormGroupInputNumber      as FormGroupTimeBalance,
  BaseFormGroupInputMultiplier  as FormGroupBandwidthBalance,
  BaseFormGroupToggleNoYes      as FormGroupVoip,
  BaseFormGroupInput            as FormGroupBypassVlan,
  BaseFormGroupChosenOne        as FormGroupBypassRole,
  BaseFormGroupTextarea         as FormGroupNotes
}
