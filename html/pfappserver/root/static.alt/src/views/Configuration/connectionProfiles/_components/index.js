import { BaseViewCollectionItem } from '../../_components/new/'
import {
  BaseFormButtonBar,
  BaseFormGroupChosenMultiple,
  BaseFormGroupChosenOne,
  BaseFormGroupInput,
  BaseFormGroupInputNumber,
  BaseFormGroupToggleDisabledEnabled
} from '@/components/new/'
import { BaseFormGroupIntervalUnit } from '@/views/Configuration/_components/new/'
import BaseFormGroupCondition from '@/views/Configuration/filterEngines/_components/BaseFormGroupCondition'
import BaseFormGroupFilter from './BaseFormGroupFilter'
import ButtonPreviewPortal from './ButtonPreviewPortal'
import TheForm from './TheForm'
import TheView from './TheView'

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
  BaseFormGroupToggleDisabledEnabled  as FormGroupUnregOnAcctStop,
  BaseFormGroupChosenOne              as FormGroupVlanPoolTechnique,
  BaseFormGroupChosenOne              as FormGroupFilterMatchStyle,
  BaseFormGroupFilter                 as FormGroupFilter,
  BaseFormGroupCondition              as FormGroupAdvancedFilter,
  BaseFormGroupChosenMultiple         as FormGroupSources,
  BaseFormGroupChosenMultiple         as FormGroupBillingTiers,
  BaseFormGroupChosenMultiple         as FormGroupProvisioners,
  BaseFormGroupChosenMultiple         as FormGroupScans,
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
  BaseFormGroupChosenMultiple         as FormGroupLocale,

  ButtonPreviewPortal,
  TheForm,
  TheView
}
