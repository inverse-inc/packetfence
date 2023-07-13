import {
  BaseFormButtonBar,
  BaseFormGroupInput,
  BaseFormGroupInputNumber,
  BaseFormGroupTextarea,
  BaseFormGroupSwitch,
} from '@/components/new/'
import { BaseFormGroupIntervalUnit } from '@/views/Configuration/_components/new/'
import { BaseViewResource } from '../../_components/new/'
import TheForm from './TheForm'
import TheView from './TheView'

export {
  BaseFormButtonBar                   as FormButtonBar,

  BaseFormGroupSwitch                 as FormGroupExposeFingerbankInfoAllTemplates,
  BaseFormGroupInput                  as FormGroupIpAddress,
  BaseFormGroupSwitch                 as FormGroupNetworkDetection,
  BaseFormGroupInput                  as FormGroupNetworkDetectionIp,
  BaseFormGroupIntervalUnit           as FormGroupNetworkDetectionInitialDelay,
  BaseFormGroupIntervalUnit           as FormGroupNetworkDetectionRetryDelay,
  BaseFormGroupIntervalUnit           as FormGroupNetworkRedirectDelay,
  BaseFormGroupInput                  as FormGroupImagePath,
  BaseFormGroupInputNumber            as FormGroupRequestTimeout,
  BaseFormGroupTextarea               as FormGroupLoadbalancersIp,
  BaseFormGroupSwitch                 as FormGroupSecureRedirect,
  BaseFormGroupSwitch                 as FormGroupStatusOnlyOnProduction,
  BaseFormGroupSwitch                 as FormGroupDetectionMecanismBypass,
  BaseFormGroupTextarea               as FormGroupDetectionMecanismUrls,
  BaseFormGroupSwitch                 as FormGroupWisprRedirection,
  BaseFormGroupSwitch                 as FormGroupRateLimiting,
  BaseFormGroupInputNumber            as FormGroupRateLimitingThreshold,
  BaseFormGroupTextarea               as FormGroupOtherDomainNames,

  BaseViewResource                    as BaseView,
  TheForm,
  TheView
}
