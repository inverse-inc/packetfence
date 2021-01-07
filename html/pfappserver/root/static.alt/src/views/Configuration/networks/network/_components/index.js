import { BaseViewResource } from '../../../_components/new/'
import {
  BaseFormButtonBar,
  BaseFormGroupInput,
  BaseFormGroupTextarea,
  BaseFormGroupToggleDisabledEnabled
} from '@/components/new/'
import {
  BaseFormGroupIntervalUnit
} from '@/views/Configuration/_components/new/'
import TheForm from './TheForm'
import TheView from './TheView'

export {
  BaseFormButtonBar                   as FormButtonBar,

  BaseFormGroupToggleDisabledEnabled  as FormGroupDhcpdetector,
  BaseFormGroupIntervalUnit           as FormGroupDhcpRateLimiting,
  BaseFormGroupToggleDisabledEnabled  as FormGroupRogueDhcpDetection,
  BaseFormGroupInput                  as FormGroupRogueinterval,
  BaseFormGroupToggleDisabledEnabled  as FormGroupHostnameChangeDetection,
  BaseFormGroupToggleDisabledEnabled  as FormGroupConnectionTypeChangeDetection,
  BaseFormGroupToggleDisabledEnabled  as FormGroupDhcpoption82logger,
  BaseFormGroupToggleDisabledEnabled  as FormGroupDhcpProcessIpv6,
  BaseFormGroupToggleDisabledEnabled  as FormGroupForceListenerUpdateOnAck,
  BaseFormGroupInput                  as FormGroupInterfaceSnat,
  BaseFormGroupTextarea               as FormGroupStaticroutes,

  BaseViewResource                    as BaseView,
  TheForm,
  TheView
}
