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
  BaseFormButtonBar                   as FormButtonBar,

  BaseFormGroupInput                  as FormGroupIdentifier,
  BaseFormGroupInput                  as FormGroupRegex,
  BaseFormGroupChosenOne              as FormGroupDomain,
  BaseFormGroupChosenOne              as FormGroupEdirSource,
  BaseFormGroupChosenOne              as FormGroupEap,
  BaseFormGroupTextarea               as FormGroupOptions,
  BaseFormGroupChosenMultiple         as FormGroupRadiusAuth,
  BaseFormGroupChosenOne              as FormGroupRadiusAuthProxyType,
  BaseFormGroupToggleDisabledEnabled  as FormGroupRadiusAuthComputeInPf,
  BaseFormGroupChosenMultiple         as FormGroupRadiusAcct,
  BaseFormGroupChosenOne              as FormGroupRadiusAcctProxyType,
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
  BaseFormGroupChosenOne              as FormGroupLdapSourceTtlsPap,

  TheForm,
  TheView
}
