import { BaseViewResource } from '../../../_components/new/'
import {
  BaseFormButtonBar,
  BaseFormGroupInput,
  BaseFormGroupInputNumber,
  BaseFormGroupTextarea,
  BaseFormGroupToggleDisabledEnabled
} from '@/components/new/'
import TheForm from './TheForm'
import TheView from './TheView'

export {
  BaseFormButtonBar                   as FormButtonBar,

  BaseFormGroupToggleDisabledEnabled  as FormGroupAccounting,
  BaseFormGroupInputNumber            as FormGroupLayer3AccountingSessionTimeout,
  BaseFormGroupInputNumber            as FormGroupLayer3AccountingSyncInterval,
  BaseFormGroupInput                  as FormGroupPortsRedirect,
  BaseFormGroupToggleDisabledEnabled  as FormGroupShouldReauthOnVlanChange,
  BaseFormGroupTextarea               as FormGroupInterfaceSnat,

  BaseViewResource                    as BaseView,
  TheForm,
  TheView
}
