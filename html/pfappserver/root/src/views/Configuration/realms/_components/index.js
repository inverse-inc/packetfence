import { BaseViewCollectionItem } from '../../_components/new/'
import {
  BaseFormButtonBar,
  BaseFormGroupChosenMultiple,
  BaseFormGroupChosenOne,
  BaseFormGroupInput,
  BaseFormGroupTextarea,
  BaseFormGroupToggleDisabledEnabled
} from '@/components/new/'
import TheForm from './TheForm'
import TheView from './TheView'

export {
  BaseViewCollectionItem              as BaseView,
  BaseFormButtonBar                   as FormButtonBar,

  BaseFormGroupInput                  as FormGroupIdentifier,
  BaseFormGroupInput                  as FormGroupRegex,
  BaseFormGroupChosenOne              as FormGroupDomain,
  BaseFormGroupChosenOne              as FormGroupEdirSource,
  BaseFormGroupChosenOne              as FormGroupEap,
  BaseFormGroupTextarea               as FormGroupOptions,
  BaseFormGroupChosenMultiple         as FormGroupRadiusAuth,
  BaseFormGroupChosenOne              as FormGroupRadiusAuthProxyType,
  BaseFormGroupToggleDisabledEnabled  as FormGroupRadiusAuthHomeServerPoolVirtualServer,
  BaseFormGroupTextarea               as FormGroupRadiusAuthVirtualServerOptions,
  BaseFormGroupToggleDisabledEnabled  as FormGroupRadiusAuthComputeInPf,
  BaseFormGroupChosenMultiple         as FormGroupRadiusAcct,
  BaseFormGroupChosenOne              as FormGroupRadiusAcctProxyType,
  BaseFormGroupToggleDisabledEnabled  as FormGroupRadiusAcctHomeServerPoolVirtualServer,
  BaseFormGroupTextarea               as FormGroupRadiusAcctVirtualServerOptions,
  BaseFormGroupTextarea               as FormGroupEduroamOptions,
  BaseFormGroupChosenMultiple         as FormGroupEduroamRadiusAuth,
  BaseFormGroupChosenOne              as FormGroupEduroamRadiusAuthProxyType,
  BaseFormGroupToggleDisabledEnabled  as FormGroupEduroamRadiusAuthComputeInPf,
  BaseFormGroupChosenMultiple         as FormGroupEduroamRadiusAcct,
  BaseFormGroupChosenOne              as FormGroupEduroamRadiusAcctProxyType,
  BaseFormGroupToggleDisabledEnabled  as FormGroupPortalStripUsername,
  BaseFormGroupToggleDisabledEnabled  as FormGroupAdminStripUsername,
  BaseFormGroupToggleDisabledEnabled  as FormGroupRadiusStripUsername,
  BaseFormGroupToggleDisabledEnabled  as FormGroupPermitCustomAttributes,
  BaseFormGroupChosenOne              as FormGroupLdapSource,
  BaseFormGroupChosenOne              as FormGroupAzureadSourceTtlsPap,
  BaseFormGroupChosenOne              as FormGroupLdapSourceTtlsPap,

  TheForm,
  TheView
}
