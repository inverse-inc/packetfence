import {
  BaseFormButtonBar,
  BaseFormGroupInput,
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
  BaseFormGroupSelectOne              as FormGroupEap,
  BaseFormGroupTextarea               as FormGroupOptions,
  BaseFormGroupSelectOne              as FormGroupRadiusAuth,
  BaseFormGroupSelectOne              as FormGroupRadiusAuthProxyType,
  BaseFormGroupToggleDisabledEnabled  as FormGroupRadiusAuthComputeInPf,
  BaseFormGroupSelectOne              as FormGroupRadiusAcctChosen,
  BaseFormGroupSelectOne              as FormGroupRadiusAcctProxyType,
  BaseFormGroupTextarea               as FormGroupEduroamOptions,
  BaseFormGroupSelectOne              as FormGroupEduroamRadiusAuth,
  BaseFormGroupSelectOne              as FormGroupEduroamRadiusAuthProxyType,
  BaseFormGroupToggleDisabledEnabled  as FormGroupEduroamRadiusAuthComputeInPf,
  BaseFormGroupSelectOne              as FormGroupEduroamRadiusAcctChosen,
  BaseFormGroupSelectOne              as FormGroupEduroamRadiusAcctProxyType,
  BaseFormGroupToggleDisabledEnabled  as FormGroupPortalStripUsername,
  BaseFormGroupToggleDisabledEnabled  as FormGroupAdminStripUsername,
  BaseFormGroupToggleDisabledEnabled  as FormGroupRadiusStripUsername,
  BaseFormGroupToggleDisabledEnabled  as FormGroupPermitCustomAttributes,
  BaseFormGroupSelectOne              as FormGroupLdapSource,

  TheForm,
  TheView
}
