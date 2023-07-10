import { BaseViewCollectionItem } from '../../_components/new/'
import {
  BaseFormButtonBar,
  BaseFormGroupChosenOne,
  BaseFormGroupInput,
  BaseFormGroupInputNumber,
  BaseFormGroupToggleDisabledEnabled,
  BaseFormGroupSwitch,
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
import InlineName from './InlineName'
import ModalDirectory from './ModalDirectory'
import ModalEdit from './ModalEdit'
import ModalView from './ModalView'
import TheFilesList from './TheFilesList'
import TheForm from './TheForm'
import TheView from './TheView'
import ToggleStatus from './ToggleStatus'

export {
  BaseViewCollectionItem              as BaseView,
  BaseFormButtonBar                   as FormButtonBar,

  BaseFormGroupInput                  as FormGroupIdentifier,
  BaseFormGroupInput                  as FormGroupDescription,
  BaseFormGroupSwitch                 as FormGroupStatus,
  BaseFormGroupChosenOne              as FormGroupRootModule,
  BaseFormGroupSwitch                 as FormGroupPreregistration,
  BaseFormGroupSwitch                 as FormGroupAutoregister,
  BaseFormGroupSwitch                 as FormGroupReuseDot1xCredentials,
  BaseFormGroupSwitch                 as FormGroupDot1xRecomputeRoleFromPortal,
  BaseFormGroupSwitch                 as FormGroupMacAuthRecomputeRoleFromPortal,
  BaseFormGroupSwitch                 as FormGroupDot1xUnsetOnUnmatch,
  BaseFormGroupSwitch                 as FormGroupDpsk,
  BaseFormGroupInput                  as FormGroupDefaultPskKey,
  BaseFormGroupSwitch                 as FormGroupUnboundDpsk,
  BaseFormGroupSwitch                 as FormGroupUnregOnAcctStop,
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
  BaseFormGroupSwitch                 as FormGroupAlwaysUseRedirecturl,
  BaseFormGroupSwitch                 as FormGroupShowManageDevicesOnMaxNodes,
  BaseFormGroupIntervalUnit           as FormGroupBlockInterval,
  BaseFormGroupInputNumber            as FormGroupSmsPinRetryLimit,
  BaseFormGroupInputNumber            as FormGroupSmsRequestLimit,
  BaseFormGroupInputNumber            as FormGroupLoginAttemptLimit,
  BaseFormGroupSwitch                 as FormGroupAccessRegistrationWhenRegistered,
  BaseFormGroupSwitch                 as FormGroupNetworkLogoff,
  BaseFormGroupSwitch                 as FormGroupNetworkLogoffPopup,
  BaseFormGroupLocales                as FormGroupLocale,

  ButtonPreviewPortal,
  InlineName,
  ModalDirectory,
  ModalEdit,
  ModalView,
  TheFilesList,
  TheForm,
  TheView,
  ToggleStatus
}
