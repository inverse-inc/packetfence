import BaseArray from './BaseArray'
import BaseForm from './BaseForm'
import BaseFormButtonBar from './BaseFormButtonBar'
import BaseFormGroup from './BaseFormGroup'
import BaseFormGroupInput from '@/components/new/BaseFormGroupInput'
import BaseFormGroupToggle from '@/components/new/BaseFormGroupToggle'
import BaseFormGroupToggleDisabledEnabled from '@/components/new/BaseFormGroupToggleDisabledEnabled'
import BaseFormGroupToggleOffOn from '@/components/new/BaseFormGroupToggleOffOn'
import BaseFormTab from './BaseFormTab'
import BaseInput from './BaseInput'
import BaseInputPassword from './BaseInputPassword'
import BaseInputGroup from './BaseInputGroup'
import BaseInputRange from './BaseInputRange'

import { mergeProps } from './utils'

export {
  // form
  BaseForm,
  BaseFormButtonBar,
  BaseFormTab,

  // form group
  BaseFormGroup,
  BaseFormGroupInput,
  BaseFormGroupToggle,
  BaseFormGroupToggleDisabledEnabled,
  BaseFormGroupToggleOffOn,

  // form inputs
  BaseInput,
  BaseInputPassword,
  BaseInputRange,

  // bootstrap wrappers
  BaseInputGroup,

  // array wrapper
  BaseArray,

  // utils
  mergeProps
}
