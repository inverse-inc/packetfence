import BaseArray from './BaseArray'
import BaseForm from './BaseForm'
import BaseFormButtonBar from './BaseFormButtonBar'
import BaseFormGroup, { props as BaseFormGroupProps } from './BaseFormGroup'
import BaseFormGroupInput, { props as BaseFormGroupInputProps } from '@/components/new/BaseFormGroupInput'
import BaseFormGroupToggle, { props as BaseFormGroupToggleProps } from '@/components/new/BaseFormGroupToggle'
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
  BaseFormGroup, BaseFormGroupProps,
  BaseFormGroupInput, BaseFormGroupInputProps,
  BaseFormGroupToggle, BaseFormGroupToggleProps,

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
