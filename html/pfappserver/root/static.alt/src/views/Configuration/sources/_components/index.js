import {
  BaseFormButtonBar,
  BaseFormGroupInput,
  BaseFormGroupInputNumber,
  BaseFormGroupInputPasswordTest,
  BaseFormGroupSelectMultiple,
  BaseFormGroupSelectOne,
} from '@/components/new/'
import BaseFormGroupAdministrationRules from './BaseFormGroupAdministrationRules'
import BaseFormGroupAuthenticationRules from './BaseFormGroupAuthenticationRules'
import BaseFormGroupHostPortEncryption from './BaseFormGroupHostPortEncryption'

import TheForm from './TheForm'
import TheView from './TheView'

export {
  BaseFormButtonBar                 as FormButtonBar,

  BaseFormGroupAdministrationRules  as FormGroupAdministrationRules,
  BaseFormGroupAuthenticationRules  as FormGroupAuthenticationRules,
  BaseFormGroupInput                as FormGroupBaseDn,
  BaseFormGroupInput                as FormGroupBindDn,
  BaseFormGroupInputNumber          as FormGroupConnectionTimeout,
  BaseFormGroupInput                as FormGroupDescription,
  BaseFormGroupInput                as FormGroupEmailAttribute,
  BaseFormGroupHostPortEncryption   as FormGroupHostPortEncryption,
  BaseFormGroupInput                as FormGroupIdentifier,
  BaseFormGroupInputPasswordTest    as FormGroupPassword,
  BaseFormGroupInput                as FormGroupPath,
  BaseFormGroupInputNumber          as FormGroupReadTimeout,
  BaseFormGroupSelectMultiple       as FormGroupRealms,
  BaseFormGroupSelectOne            as FormGroupScope,
  BaseFormGroupSelectMultiple       as FormGroupSearchAttributes,
  BaseFormGroupInput                as FormGroupSearchAttributesAppend,
  BaseFormGroupSelectOne            as FormGroupUsernameAttribute,
  BaseFormGroupInputNumber          as FormGroupWriteTimeout,

  TheForm,
  TheView
}
