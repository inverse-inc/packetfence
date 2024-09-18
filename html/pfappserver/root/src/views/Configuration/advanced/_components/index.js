import {BaseViewResource} from '../../_components/new/'
import {
  BaseFormButtonBar,
  BaseFormGroupChosenOne,
  BaseFormGroupInput,
  BaseFormGroupInputNumber,
  BaseFormGroupSwitch,
  BaseFormGroupTextarea,
} from '@/components/new/'
import {BaseFormGroupIntervalUnit} from '@/views/Configuration/_components/new/'
import BaseFormGroupOpenidAttributes from './BaseFormGroupOpenidAttributes'
import TheForm from './TheForm'
import TheView from './TheView'

export {
  BaseFormButtonBar as FormButtonBar,

  BaseFormGroupIntervalUnit as FormGroupAccountingTimebucketSize,
  BaseFormGroupSwitch as FormGroupActiveDirectoryOsJoinCheckBypass,
  BaseFormGroupSwitch as FormGroupAdminCspSecurityHeaders,
  BaseFormGroupIntervalUnit as FormGroupApiInactivityTimeout,
  BaseFormGroupIntervalUnit as FormGroupApiMaxExpiration,
  BaseFormGroupSwitch as FormGroupConfigurator,
  BaseFormGroupChosenOne as FormGroupHashPasswords,
  BaseFormGroupInput as FormGroupHashingCost,
  BaseFormGroupChosenOne as FormGroupLanguage,
  BaseFormGroupTextarea as FormGroupLdapAttributes,
  BaseFormGroupSwitch as FormGroupLocationlogCloseOnAccountingStop,
  BaseFormGroupSwitch as FormGroupMultihost,
  BaseFormGroupSwitch as FormGroupNetflowOnAllNetworks,
  BaseFormGroupOpenidAttributes as FormGroupOpenidAttributes,
  BaseFormGroupInputNumber as FormGroupPffilterProcesses,
  BaseFormGroupInputNumber as FormGroupPfperlApiProcesses,
  BaseFormGroupInputNumber as FormGroupPfperlApiTimeout,
  BaseFormGroupSwitch as FormGroupPortalCspSecurityHeaders,
  BaseFormGroupInput as FormGroupPfupdateCustomScriptPath,
  BaseFormGroupSwitch as FormGroupScanOnAccounting,
  BaseFormGroupChosenOne as FormGroupSourceToSendSmsWhenCreatingUsers,
  BaseFormGroupInputNumber as FormGroupTimingStatsLevel,
  BaseFormGroupSwitch as FormGroupUpdateIplogWithAccounting,
  BaseFormGroupSwitch as FormGroupUpdateIplogWithExternalPortalRequests,

  BaseViewResource as BaseView,
  TheForm,
  TheView
}
