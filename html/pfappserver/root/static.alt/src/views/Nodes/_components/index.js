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
import FormGroupPid from './FormGroupPid'
import TheForm from './TheForm'
import NodeView from './NodeView'

export {
  BaseFormButtonBar                   as FormButtonBar,
  BaseInputChosenOne                  as FormSecurityEvents,

  FormGroupPid,
  BaseFormGroupChosenOne              as FormGroupStatus,
  BaseFormGroupChosenOne              as FormGroupRole,
  BaseFormGroupInputDateTime          as FormGroupUnregdate,
  BaseFormGroupInputNumber            as FormGroupTimeBalance,
  BaseFormGroupInputMultiplier        as FormGroupBandwidthBalance,
  BaseFormGroupToggleNoYes            as FormGroupVoip,
  BaseFormGroupInput                  as FormGroupBypassVlan,
  BaseFormGroupChosenOne              as FormGroupBypassRole,
  BaseFormGroupTextarea               as FormGroupNotes,

  TheForm,
  NodeView
}
