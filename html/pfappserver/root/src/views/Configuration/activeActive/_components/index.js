import {BaseViewResource} from '../../_components/new/'
import {
  BaseFormButtonBar,
  BaseFormGroupInput,
  BaseFormGroupInputPassword,
  BaseFormGroupSwitch,
} from '@/components/new/'
import {BaseFormGroupIntervalUnit} from '@/views/Configuration/_components/new/'
import TheForm from './TheForm'
import TheView from './TheView'

export {
  BaseFormButtonBar as FormButtonBar,

  BaseFormGroupSwitch as FormGroupAuthOnManagement,
  BaseFormGroupSwitch as FormGroupCentralizedDeauth,
  BaseFormGroupSwitch as FormGroupCentralizeVips,
  BaseFormGroupIntervalUnit as FormGroupConflictResolutionThreshold,
  BaseFormGroupSwitch as FormGroupDnsOnVipOnly,
  BaseFormGroupSwitch as FormGroupFirewallSsoOnManagement,
  BaseFormGroupSwitch as FormGroupGatewayOnVipOnly,
  BaseFormGroupSwitch as FormGroupGaleraReplication,
  BaseFormGroupInput as FormGroupGaleraReplicationUsername,
  BaseFormGroupInputPassword as FormGroupGaleraReplicationPassword,
  BaseFormGroupInputPassword as FormGroupPassword,
  BaseFormGroupSwitch as FormGroupPortalOnManagement,
  BaseFormGroupSwitch as FormGroupRadiusProxyWithVip,
  BaseFormGroupSwitch as FormGroupUseVipForDeauth,
  BaseFormGroupInput as FormGroupVirtualRouterIdentifier,
  BaseFormGroupSwitch as FormGroupVrrpUnicast,
  BaseFormGroupSwitch as FormGroupProbeMysqlFromHaproxyDb,

  BaseViewResource as BaseView,
  TheForm,
  TheView
}
