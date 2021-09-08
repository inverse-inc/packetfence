import { BaseViewCollectionItem } from '@/views/Configuration/_components/new/'
import {
  BaseFormButtonBar,
  BaseFormGroupChosenOne,
  BaseFormGroupInput,
  BaseFormGroupInputNumber,
  BaseFormGroupToggleDisabledEnabled
} from '@/components/new/'
import { BaseFormGroupIntervalUnit } from '@/views/Configuration/_components/new/'
import BaseFormGroupBillingTiers from './BaseFormGroupBillingTiers'
import BaseFormGroupCondition from '@/views/Configuration/filterEngines/_components/BaseFormGroupCondition'
import BaseFormGroupFilter from './BaseFormGroupFilter'
import BaseFormGroupLocales from './BaseFormGroupLocales'
import BaseFormGroupProvisioners from './BaseFormGroupProvisioners'
import BaseFormGroupScanners from './BaseFormGroupScanners'
import BaseFormGroupSources from './BaseFormGroupSources'
import ButtonPreviewPortal from './ButtonPreviewPortal'
import ModalDirectory from './ModalDirectory'
import ModalFile from './ModalFile'
import TheFilesList from './TheFilesList'
import TheForm from './TheForm'
import TheView from './TheView'
import ToggleStatus from './ToggleStatus'

export {
  BaseViewCollectionItem              as BaseView,
  BaseFormButtonBar                   as FormButtonBar,

  BaseFormGroupInput                  as FormGroupIdentifier,
  BaseFormGroupInput                  as FormGroupDescription,
  BaseFormGroupToggleDisabledEnabled  as FormGroupStatus,
  BaseFormGroupChosenOne              as FormGroupRootModule,
  BaseFormGroupToggleDisabledEnabled  as FormGroupPreregistration,
  BaseFormGroupToggleDisabledEnabled  as FormGroupAutoregister,
  BaseFormGroupToggleDisabledEnabled  as FormGroupReuseDot1xCredentials,
  BaseFormGroupToggleDisabledEnabled  as FormGroupDot1xRecomputeRoleFromPortal,
  BaseFormGroupToggleDisabledEnabled  as FormGroupMacAuthRecomputeRoleFromPortal,
  BaseFormGroupToggleDisabledEnabled  as FormGroupDot1xUnsetOnUnmatch,
  BaseFormGroupToggleDisabledEnabled  as FormGroupDpsk,
  BaseFormGroupInput                  as FormGroupDefaultPskKey,
  BaseFormGroupToggleDisabledEnabled  as FormGroupUnboundDpsk,
  BaseFormGroupToggleDisabledEnabled  as FormGroupUnregOnAcctStop,
  BaseFormGroupChosenOne              as FormGroupVlanPoolTechnique,
  BaseFormGroupChosenOne              as FormGroupFilterMatchStyle,
  BaseFormGroupFilter                 as FormGroupFilter,
  BaseFormGroupCondition              as FormGroupAdvancedFilter,
  BaseFormGroupSources                as FormGroupSources,
  BaseFormGroupBillingTiers           as FormGroupBillingTiers,
  BaseFormGroupProvisioners           as FormGroupProvisioners,
  BaseFormGroupScanners               as FormGroupScans,
  BaseFormGroupChosenOne              as FormGroupSelfService,

  BaseFormGroupInput                  as FormGroupLogo,
  BaseFormGroupInput                  as FormGroupRedirectUrl,
  BaseFormGroupToggleDisabledEnabled  as FormGroupAlwaysUseRedirecturl,
  BaseFormGroupIntervalUnit           as FormGroupBlockInterval,
  BaseFormGroupInputNumber            as FormGroupSmsPinRetryLimit,
  BaseFormGroupInputNumber            as FormGroupSmsRequestLimit,
  BaseFormGroupInputNumber            as FormGroupLoginAttemptLimit,
  BaseFormGroupToggleDisabledEnabled  as FormGroupAccessRegistrationWhenRegistered,
  BaseFormGroupToggleDisabledEnabled  as FormGroupNetworkLogoff,
  BaseFormGroupToggleDisabledEnabled  as FormGroupNetworkLogoffPopup,
  BaseFormGroupLocales                as FormGroupLocale,

  ButtonPreviewPortal,
  ModalDirectory,
  ModalFile,
  TheFilesList,
  TheForm,
  TheView,
  ToggleStatus
}
