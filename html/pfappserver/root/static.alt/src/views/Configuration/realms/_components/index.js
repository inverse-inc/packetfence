import {
  BaseFormButtonBar,
  BaseFormGroupInput,
  BaseFormGroupSelectMultiple,
  BaseFormGroupSelectOne,
  BaseFormGroupTextarea,
  BaseFormGroupToggleDisabledEnabled
} from '@/components/new/'
import TheForm from './TheForm'
import TheView from './TheView'

export {
  BaseFormButtonBar                   as FormButtonBar,

  BaseFormGroupInput                  as FormGroupIdentifier,
  BaseFormGroupInput                  as FormGroupRegex,
  BaseFormGroupSelectOne              as FormGroupDomain,
  BaseFormGroupSelectOne              as FormGroupEdirSource,
  BaseFormGroupSelectOne              as FormGroupEap,
  BaseFormGroupTextarea               as FormGroupOptions,
  BaseFormGroupSelectMultiple         as FormGroupRadiusAuth,
  BaseFormGroupSelectOne              as FormGroupRadiusAuthProxyType,
  BaseFormGroupToggleDisabledEnabled  as FormGroupRadiusAuthComputeInPf,
  BaseFormGroupSelectMultiple         as FormGroupRadiusAcct,
  BaseFormGroupSelectOne              as FormGroupRadiusAcctProxyType,
  BaseFormGroupTextarea               as FormGroupEduroamOptions,
  BaseFormGroupSelectMultiple         as FormGroupEduroamRadiusAuth,
  BaseFormGroupSelectOne              as FormGroupEduroamRadiusAuthProxyType,
  BaseFormGroupToggleDisabledEnabled  as FormGroupEduroamRadiusAuthComputeInPf,
  BaseFormGroupSelectMultiple         as FormGroupEduroamRadiusAcct,
  BaseFormGroupSelectOne              as FormGroupEduroamRadiusAcctProxyType,
  BaseFormGroupToggleDisabledEnabled  as FormGroupPortalStripUsername,
  BaseFormGroupToggleDisabledEnabled  as FormGroupAdminStripUsername,
  BaseFormGroupToggleDisabledEnabled  as FormGroupRadiusStripUsername,
  BaseFormGroupToggleDisabledEnabled  as FormGroupPermitCustomAttributes,
  BaseFormGroupSelectOne              as FormGroupLdapSource,
  BaseFormGroupSelectOne              as FormGroupLdapSourceTtlsPap,

  TheForm,
  TheView
}
