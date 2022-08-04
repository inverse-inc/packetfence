import {
  BaseFormButtonBar,
  BaseFormGroupTextarea,
  BaseFormGroupToggleDisabledEnabled
} from '@/components/new/'
import { BaseViewResource } from '../../../_components/new/'
import AlertServices from './AlertServices'
import TheForm from './TheForm'
import TheView from './TheView'

export {
  BaseFormButtonBar                   as FormButtonBar,

  BaseFormGroupToggleDisabledEnabled  as FormGroupRecordAccountingInSql,
  BaseFormGroupToggleDisabledEnabled  as FormGroupFilterInPacketfenceAuthorize,
  BaseFormGroupToggleDisabledEnabled  as FormGroupFilterInPacketfencePreProxy,
  BaseFormGroupToggleDisabledEnabled  as FormGroupFilterInPacketfencePostProxy,
  BaseFormGroupToggleDisabledEnabled  as FormGroupFilterInPacketfencePreacct,
  BaseFormGroupToggleDisabledEnabled  as FormGroupFilterInPacketfenceAccounting,
  BaseFormGroupToggleDisabledEnabled  as FormGroupFilterInPacketfenceTunnelAuthorize,
  BaseFormGroupToggleDisabledEnabled  as FormGroupFilterInEduroamAuthorize,
  BaseFormGroupToggleDisabledEnabled  as FormGroupFilterInEduroamPreProxy,
  BaseFormGroupToggleDisabledEnabled  as FormGroupFilterInEduroamPostProxy,
  BaseFormGroupToggleDisabledEnabled  as FormGroupFilterInEduroamPreacct,
  BaseFormGroupToggleDisabledEnabled  as FormGroupLocalAuth,
  BaseFormGroupToggleDisabledEnabled  as FormGroupNtlmRedisCache,
  BaseFormGroupToggleDisabledEnabled  as FormGroupProcessBandwidthAccounting,
  BaseFormGroupTextarea               as FormGroupRadiusAttributes,
  BaseFormGroupToggleDisabledEnabled  as FormGroupNormalizeRadiusMachineAuthUsername,
  BaseFormGroupTextarea               as FormGroupUsernameAttributes,

  AlertServices,
  BaseViewResource                    as BaseView,
  TheForm,
  TheView
}
