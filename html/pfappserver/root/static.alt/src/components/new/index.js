import BaseArray from './BaseArray'
import BaseForm from './BaseForm'
import BaseFormGroup, { props as BaseFormGroupProps } from './BaseFormGroup'
import BaseFormGroupInput, { props as BaseFormGroupInputProps } from '@/components/new/BaseFormGroupInput'
import BaseInput from './BaseInput'
import BaseInputPassword from './BaseInputPassword'
import BaseInputGroup from './BaseInputGroup'
import { mergeProps } from './utils'

export {
  // form
  BaseForm,

  // form group
  BaseFormGroup, BaseFormGroupProps,
  BaseFormGroupInput, BaseFormGroupInputProps,

  // form inputs
  BaseInput,
  BaseInputPassword,

  // bootstrap wrappers
  BaseInputGroup,

  // array wrapper
  BaseArray,

  // utils
  mergeProps
}
