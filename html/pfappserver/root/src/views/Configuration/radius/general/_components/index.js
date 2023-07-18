import {
  BaseFormButtonBar,
  BaseFormGroupInputNumber,
  BaseFormGroupSwitch,
  BaseFormGroupTextarea
} from '@/components/new/'
import {BaseViewResource} from '../../../_components/new/'
import TheForm from './TheForm'
import TheView from './TheView'

export {
  BaseFormButtonBar as FormButtonBar,

  BaseFormGroupSwitch as FormGroupRecordAccountingInSql,
  BaseFormGroupSwitch as FormGroupFilterInPacketfenceAuthorize,
  BaseFormGroupSwitch as FormGroupFilterInPacketfencePreProxy,
  BaseFormGroupSwitch as FormGroupFilterInPacketfencePostProxy,
  BaseFormGroupSwitch as FormGroupFilterInPacketfencePreacct,
  BaseFormGroupSwitch as FormGroupFilterInPacketfenceAccounting,
  BaseFormGroupSwitch as FormGroupFilterInPacketfenceTunnelAuthorize,
  BaseFormGroupSwitch as FormGroupFilterInEduroamAuthorize,
  BaseFormGroupSwitch as FormGroupFilterInEduroamPreProxy,
  BaseFormGroupSwitch as FormGroupFilterInEduroamPostProxy,
  BaseFormGroupSwitch as FormGroupFilterInEduroamPreacct,
  BaseFormGroupSwitch as FormGroupLocalAuth,
  BaseFormGroupSwitch as FormGroupNtlmRedisCache,
  BaseFormGroupSwitch as FormGroupProcessBandwidthAccounting,
  BaseFormGroupTextarea as FormGroupRadiusAttributes,
  BaseFormGroupSwitch as FormGroupNormalizeRadiusMachineAuthUsername,
  BaseFormGroupTextarea as FormGroupUsernameAttributes,
  BaseFormGroupInputNumber as FormGroupPfacctWorkers,
  BaseFormGroupInputNumber as FormGroupPfacctWorkQueueSize,

  BaseViewResource as BaseView,
  TheForm,
  TheView
}
