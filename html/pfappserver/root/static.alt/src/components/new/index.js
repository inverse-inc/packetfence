import BaseArray from './BaseArray'
import BaseButtonDelete from './BaseButtonDelete'
import BaseForm from './BaseForm'
import BaseFormButtonBar from './BaseFormButtonBar'
import BaseFormGroup from './BaseFormGroup'
import BaseFormGroupArray, { props as BaseFormGroupArrayProps } from './BaseFormGroupArray'
import BaseFormGroupArrayDraggable, { props as BaseFormGroupArrayDraggableProps } from './BaseFormGroupArrayDraggable'
import BaseFormGroupChosenMultiple from './BaseFormGroupChosenMultiple'
import BaseFormGroupChosenOne from './BaseFormGroupChosenOne'
import BaseFormGroupInput from './BaseFormGroupInput'
import BaseFormGroupInputNumber from './BaseFormGroupInputNumber'
import BaseFormGroupInputPassword from './BaseFormGroupInputPassword'
import BaseFormGroupInputPasswordTest, { props as BaseFormGroupInputPasswordTestProps } from './BaseFormGroupInputPasswordTest'
import BaseFormGroupTextarea from './BaseFormGroupTextarea'
import BaseFormGroupToggle, { props as BaseFormGroupToggleProps } from './BaseFormGroupToggle'
import BaseFormGroupToggleDisabledEnabled from './BaseFormGroupToggleDisabledEnabled'
import BaseFormGroupToggleNoYes from './BaseFormGroupToggleNoYes'
import BaseFormGroupToggleNY from './BaseFormGroupToggleNY'
import BaseFormGroupToggleOffOn from './BaseFormGroupToggleOffOn'
import BaseFormTab from './BaseFormTab'
import BaseInput from './BaseInput'
import BaseInputArray, { props as BaseInputArrayProps } from './BaseInputArray'
import BaseInputChosenMultiple from './BaseInputChosenMultiple'
import BaseInputChosenOne from './BaseInputChosenOne'
import BaseInputChosenOneSearchable from './BaseInputChosenOneSearchable'
import BaseInputGroup from './BaseInputGroup'
import BaseInputGroupMultiplier from './BaseInputGroupMultiplier'
import BaseInputNumber from './BaseInputNumber'
import BaseInputPassword from './BaseInputPassword'
import BaseInputRange from './BaseInputRange'
import BaseInputToggle, { props as BaseInputToggleProps } from './BaseInputToggle'
import BaseInputToggleAdvancedMode from './BaseInputToggleAdvancedMode'
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
  BaseFormGroupArray, BaseFormGroupArrayProps,
  BaseFormGroupArrayDraggable, BaseFormGroupArrayDraggableProps,
  BaseFormGroupChosenMultiple,
  BaseFormGroupChosenOne,
  BaseFormGroupInput,
  BaseFormGroupInputNumber,
  BaseFormGroupInputPassword,
  BaseFormGroupInputPasswordTest, BaseFormGroupInputPasswordTestProps,
  BaseFormGroupTextarea,
  BaseFormGroupToggle, BaseFormGroupToggleProps,
  BaseFormGroupToggleDisabledEnabled,
  BaseFormGroupToggleNoYes,
  BaseFormGroupToggleNY,
  BaseFormGroupToggleOffOn,

  // form inputs
  BaseInput,
  BaseInputArray, BaseInputArrayProps,
  BaseInputChosenMultiple,
  BaseInputChosenOne,
  BaseInputChosenOneSearchable,
  BaseInputGroup,
  BaseInputNumber,
  BaseInputPassword,
  BaseInputRange,
  BaseInputToggle, BaseInputToggleProps,
  BaseInputToggleAdvancedMode,

  // bootstrap wrappers
  BaseInputGroupMultiplier,

  // array wrapper
  BaseArray,

  // buttons
  BaseButtonDelete,

  // utils
  mergeProps
}
