import { BaseViewResource } from '../../_components/new/'
import {
  BaseFormButtonBar,
  BaseFormGroupChosenOne,
  BaseFormGroupInput,
  BaseFormGroupInputNumber,
  BaseFormGroupTextarea,
  BaseFormGroupToggleDisabledEnabled
} from '@/components/new/'
import {
  BaseFormGroupIntervalUnit
} from '@/views/Configuration/_components/new/'
import AlertServices from './AlertServices'
import TheForm from './TheForm'
import TheView from './TheView'

export {
  BaseFormButtonBar                   as FormButtonBar,

  BaseFormGroupIntervalUnit           as FormGroupAccountingTimebucketSize,
  BaseFormGroupToggleDisabledEnabled  as FormGroupActiveDirectoryOsJoinCheckBypass,
  BaseFormGroupToggleDisabledEnabled  as FormGroupAdminCspSecurityHeaders,
  BaseFormGroupIntervalUnit           as FormGroupApiInactivityTimeout,
  BaseFormGroupIntervalUnit           as FormGroupApiMaxExpiration,
  BaseFormGroupToggleDisabledEnabled  as FormGroupConfigurator,
  BaseFormGroupChosenOne              as FormGroupHashPasswords,
  BaseFormGroupInput                  as FormGroupHashingCost,
  BaseFormGroupChosenOne              as FormGroupLanguage,
  BaseFormGroupTextarea               as FormGroupLdapAttributes,
  BaseFormGroupToggleDisabledEnabled  as FormGroupLocationlogCloseOnAccountingStop,
  BaseFormGroupToggleDisabledEnabled  as FormGroupMultihost,
  BaseFormGroupToggleDisabledEnabled  as FormGroupNetflowOnAllNetworks,
  BaseFormGroupInput                  as FormGroupOpenidAttributes,
  BaseFormGroupInputNumber            as FormGroupPffilterProcesses,
  BaseFormGroupInputNumber            as FormGroupPfperlApiProcesses,
  BaseFormGroupInputNumber            as FormGroupPfperlApiTimeout,
  BaseFormGroupToggleDisabledEnabled  as FormGroupPortalCspSecurityHeaders,
  BaseFormGroupToggleDisabledEnabled  as FormGroupScanOnAccounting,
  BaseFormGroupChosenOne              as FormGroupSourceToSendSmsWhenCreatingUsers,
  BaseFormGroupToggleDisabledEnabled  as FormGroupSsoOnAccessReevaluation,
  BaseFormGroupToggleDisabledEnabled  as FormGroupSsoOnAccounting,
  BaseFormGroupToggleDisabledEnabled  as FormGroupSsoOnDhcp,
  BaseFormGroupInputNumber            as FormGroupTimingStatsLevel,
  BaseFormGroupToggleDisabledEnabled  as FormGroupUpdateIplogWithAccounting,
  BaseFormGroupToggleDisabledEnabled  as FormGroupUpdateIplogWithExternalPortalRequests,

  BaseViewResource                    as BaseView,
  AlertServices,
  TheForm,
  TheView
}
