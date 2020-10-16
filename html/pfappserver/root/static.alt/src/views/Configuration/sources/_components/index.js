import {
  BaseFormButtonBar,
  BaseFormGroupChosenMultiple,
  BaseFormGroupChosenOne,
  BaseFormGroupInput,
  BaseFormGroupInputNumber,
  BaseFormGroupInputPasswordTest,
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
  BaseFormGroupChosenMultiple       as FormGroupRealms,
  BaseFormGroupChosenOne            as FormGroupScope,
  BaseFormGroupChosenMultiple       as FormGroupSearchAttributes,
  BaseFormGroupInput                as FormGroupSearchAttributesAppend,
  BaseFormGroupChosenOne            as FormGroupUsernameAttribute,
  BaseFormGroupInputNumber          as FormGroupWriteTimeout,

  TheForm,
  TheView
}
