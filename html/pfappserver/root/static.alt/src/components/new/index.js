import BaseArray from './BaseArray'
import BaseForm from './BaseForm'
import BaseFormButtonBar from './BaseFormButtonBar'
import BaseFormGroup from './BaseFormGroup'
import BaseFormGroupArrayDraggable, { props as BaseFormGroupArrayDraggableProps } from './BaseFormGroupArrayDraggable'
import BaseFormGroupInput from './BaseFormGroupInput'
import BaseFormGroupSelectMultiple from './BaseFormGroupSelectMultiple'
import BaseFormGroupSelectOne from './BaseFormGroupSelectOne'
import BaseFormGroupTextarea from './BaseFormGroupTextarea'
import BaseFormGroupToggle from './BaseFormGroupToggle'
import BaseFormGroupToggleDisabledEnabled from './BaseFormGroupToggleDisabledEnabled'
import BaseFormGroupToggleOffOn from './BaseFormGroupToggleOffOn'
import BaseFormTab from './BaseFormTab'
import BaseInput from './BaseInput'
import BaseInputNumber from './BaseInputNumber'
import BaseInputPassword from './BaseInputPassword'
import BaseInputGroupMultiplier from './BaseInputGroupMultiplier'
import BaseInputRange from './BaseInputRange'
import BaseInputSelectMultiple from './BaseInputSelectMultiple'
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
  BaseFormGroupArrayDraggable, BaseFormGroupArrayDraggableProps,
  BaseFormGroupInput,
  BaseFormGroupSelectMultiple,
  BaseFormGroupSelectOne,
  BaseFormGroupTextarea,
  BaseFormGroupToggle,
  BaseFormGroupToggleDisabledEnabled,
  BaseFormGroupToggleOffOn,

  // form inputs
  BaseInput,
  BaseInputNumber,
  BaseInputPassword,
  BaseInputRange,
  BaseInputSelectMultiple,
  BaseInputSelectOne,

  // bootstrap wrappers
  BaseInputGroupMultiplier,

  // array wrapper
  BaseArray,

  // utils
  mergeProps
}
