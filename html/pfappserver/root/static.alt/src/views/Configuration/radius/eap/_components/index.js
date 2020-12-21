import {
  BaseFormButtonBar,
  BaseFormGroupChosenMultiple,
  BaseFormGroupChosenOne,
  BaseFormGroupInput,
  BaseFormGroupInputNumber
} from '@/components/new/'
import { BaseViewCollectionItem } from '../../../_components/new/'
import {
  AlertServices,
  BaseFormGroupToggleNoYesDefault
} from '../../_components/'
import TheForm from './TheForm'
import TheView from './TheView'

export {
  BaseFormButtonBar               as FormButtonBar,

  BaseFormGroupInput              as FormGroupIdentifier,
  BaseFormGroupChosenOne          as FormGroupDefaultEapType,
  BaseFormGroupInputNumber        as FormGroupTimerExpire,
  BaseFormGroupToggleNoYesDefault as FormGroupIgnoreUnknownEapTypes,
  BaseFormGroupToggleNoYesDefault as FormGroupCiscoAccountingUsernameBug,
  BaseFormGroupInputNumber        as FormGroupMaxSessions,
  BaseFormGroupChosenMultiple     as FormGroupEapAuthenticationTypes,
  BaseFormGroupChosenOne          as FormGroupTlsTlsprofile,
  BaseFormGroupChosenOne          as FormGroupTtlsTlsprofile,
  BaseFormGroupChosenOne          as FormGroupPeapTlsprofile,
  BaseFormGroupChosenOne          as FormGroupFastConfig,

  BaseViewCollectionItem          as BaseView,
  AlertServices,
  TheForm,
  TheView
}
