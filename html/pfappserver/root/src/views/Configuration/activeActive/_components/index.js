import { BaseViewResource } from '../../_components/new/'
import {
  BaseFormButtonBar,
  BaseFormGroupInput,
  BaseFormGroupInputPassword,
  BaseFormGroupToggleDisabledEnabled
} from '@/components/new/'
import {
  BaseFormGroupIntervalUnit
} from '@/views/Configuration/_components/new/'
import TheForm from './TheForm'
import TheView from './TheView'

export {
  BaseFormButtonBar                   as FormButtonBar,

  BaseFormGroupToggleDisabledEnabled  as FormGroupAuthOnManagement,
  BaseFormGroupToggleDisabledEnabled  as FormGroupCentralizedDeauth,
  BaseFormGroupIntervalUnit           as FormGroupConflictResolutionThreshold,
  BaseFormGroupToggleDisabledEnabled  as FormGroupDnsOnVipOnly,
  BaseFormGroupToggleDisabledEnabled  as FormGroupGatewayOnVipOnly,
  BaseFormGroupToggleDisabledEnabled  as FormGroupGaleraReplication,
  BaseFormGroupInput                  as FormGroupGaleraReplicationUsername,
  BaseFormGroupInputPassword          as FormGroupGaleraReplicationPassword,
  BaseFormGroupInputPassword          as FormGroupPassword,
  BaseFormGroupInput                  as FormGroupVirtualRouterIdentifier,
  BaseFormGroupToggleDisabledEnabled  as FormGroupVrrpUnicast,

  BaseViewResource                    as BaseView,
  TheForm,
  TheView
}
