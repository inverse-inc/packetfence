import {
  BaseFormButtonBar,
  BaseFormGroupInput,
  BaseFormGroupInputNumber,
  BaseFormGroupTextarea,
  BaseFormGroupToggleDisabledEnabled
} from '@/components/new/'
import { BaseFormGroupIntervalUnit } from '@/views/Configuration/_components/new/'
import { BaseViewResource } from '../../_components/new/'
import AlertServices from './AlertServices'
import TheForm from './TheForm'
import TheView from './TheView'

export {
  BaseFormButtonBar                   as FormButtonBar,

  BaseFormGroupInput                  as FormGroupIpAddress,
  BaseFormGroupToggleDisabledEnabled  as FormGroupNetworkDetection,
  BaseFormGroupInput                  as FormGroupNetworkDetectionIp,
  BaseFormGroupIntervalUnit           as FormGroupNetworkDetectionInitialDelay,
  BaseFormGroupIntervalUnit           as FormGroupNetworkDetectionRetryDelay,
  BaseFormGroupIntervalUnit           as FormGroupNetworkRedirectDelay,
  BaseFormGroupInput                  as FormGroupImagePath,
  BaseFormGroupInputNumber            as FormGroupRequestTimeout,
  BaseFormGroupTextarea               as FormGroupLoadbalancersIp,
  BaseFormGroupToggleDisabledEnabled  as FormGroupSecureRedirect,
  BaseFormGroupToggleDisabledEnabled  as FormGroupStatusOnlyOnProduction,
  BaseFormGroupToggleDisabledEnabled  as FormGroupDetectionMecanismBypass,
  BaseFormGroupTextarea               as FormGroupDetectionMecanismUrls,
  BaseFormGroupToggleDisabledEnabled  as FormGroupwWisprRedirection,
  BaseFormGroupToggleDisabledEnabled  as FormGroupRateLimiting,
  BaseFormGroupInputNumber            as FormGroupRateLimitingThreshold,
  BaseFormGroupTextarea               as FormGroupOtherDomainNames,

  BaseViewResource                    as BaseView,
  AlertServices,
  TheForm,
  TheView
}
