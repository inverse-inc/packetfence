import BaseArray from './BaseArray'
import BaseForm from './BaseForm'
import BaseFormButtonBar from './BaseFormButtonBar'
import BaseFormGroup from './BaseFormGroup'
import BaseFormGroupArrayDraggable, { props as BaseFormGroupArrayDraggableProps } from './BaseFormGroupArrayDraggable'
import BaseFormGroupChosenMultiple from './BaseFormGroupChosenMultiple'
import BaseFormGroupChosenOne from './BaseFormGroupChosenOne'
import BaseFormGroupInput from './BaseFormGroupInput'
import BaseFormGroupInputNumber from './BaseFormGroupInputNumber'
import BaseFormGroupInputPassword from './BaseFormGroupInputPassword'
import BaseFormGroupInputPasswordTest, { props as BaseFormGroupInputPasswordTestProps } from './BaseFormGroupInputPasswordTest'
import BaseFormGroupTextarea from './BaseFormGroupTextarea'
import BaseFormGroupToggle from './BaseFormGroupToggle'
import BaseFormGroupToggleDisabledEnabled from './BaseFormGroupToggleDisabledEnabled'
import BaseFormGroupToggleNoYes from './BaseFormGroupToggleNoYes'
import BaseFormGroupToggleOffOn from './BaseFormGroupToggleOffOn'
import BaseFormTab from './BaseFormTab'
import BaseInput from './BaseInput'
import BaseInputChosenMultiple from './BaseInputChosenMultiple'
import BaseInputChosenOne from './BaseInputChosenOne'
import BaseInputGroup from './BaseInputGroup'
import BaseInputNumber from './BaseInputNumber'
import BaseInputPassword from './BaseInputPassword'
import BaseInputGroupMultiplier from './BaseInputGroupMultiplier'
import BaseInputRange from './BaseInputRange'
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
  BaseFormGroupArrayDraggable, BaseFormGroupArrayDraggableProps,
  BaseFormGroupChosenMultiple,
  BaseFormGroupChosenOne,
  BaseFormGroupInput,
  BaseFormGroupInputNumber,
  BaseFormGroupInputPassword,
  BaseFormGroupInputPasswordTest, BaseFormGroupInputPasswordTestProps,
  BaseFormGroupTextarea,
  BaseFormGroupToggle,
  BaseFormGroupToggleDisabledEnabled,
  BaseFormGroupToggleNoYes,
  BaseFormGroupToggleOffOn,

  // form inputs
  BaseInput,
  BaseInputChosenMultiple,
  BaseInputChosenOne,
  BaseInputGroup,
  BaseInputNumber,
  BaseInputPassword,
  BaseInputRange,

  // bootstrap wrappers
  BaseInputGroupMultiplier,

  // array wrapper
  BaseArray,

  // utils
  mergeProps
}
