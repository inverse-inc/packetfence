import BaseArray from './BaseArray'
import BaseForm from './BaseForm'
import BaseFormButtonBar from './BaseFormButtonBar'
import BaseFormGroup from './BaseFormGroup'
import BaseFormGroupInput from './BaseFormGroupInput'
import BaseFormGroupSelectMultiple from './BaseFormGroupSelectMultiple'
import BaseFormGroupSelectOne from './BaseFormGroupSelectOne'
import BaseFormGroupTextarea from './BaseFormGroupTextarea'
import BaseFormGroupToggle from './BaseFormGroupToggle'
import BaseFormGroupToggleDisabledEnabled from './BaseFormGroupToggleDisabledEnabled'
import BaseFormGroupToggleOffOn from './BaseFormGroupToggleOffOn'
import BaseFormTab from './BaseFormTab'
import BaseInput from './BaseInput'
import BaseInputPassword from './BaseInputPassword'
import BaseInputGroup from './BaseInputGroup'
import BaseInputRange from './BaseInputRange'
import BaseInputSelectOne from './BaseInputSelectOne'
import BaseView from './BaseView'

import { mergeProps } from './utils'

export {
  // view
  BaseView,

  // form
  BaseForm,
  BaseFormButtonBar,
  BaseFormTab,

  // form group
  BaseFormGroup,
  BaseFormGroupInput,
  BaseFormGroupSelectMultiple,
  BaseFormGroupSelectOne,
  BaseFormGroupTextarea,
  BaseFormGroupToggle,
  BaseFormGroupToggleDisabledEnabled,
  BaseFormGroupToggleOffOn,

  // form inputs
  BaseInput,
  BaseInputPassword,
  BaseInputRange,
  BaseInputSelectOne,

  // bootstrap wrappers
  BaseInputGroup,

  // array wrapper
  BaseArray,

  // utils
  mergeProps
}
