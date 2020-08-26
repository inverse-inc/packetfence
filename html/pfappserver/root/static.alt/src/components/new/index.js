import BaseArray from './BaseArray'
import BaseForm from './BaseForm'
import BaseFormGroup, { props as BaseFormGroupProps } from './BaseFormGroup'
import BaseFormGroupInput, { props as BaseFormGroupInputProps } from '@/components/new/BaseFormGroupInput'
import BaseInput from './BaseInput'
import BaseInputPassword from './BaseInputPassword'
import BaseInputGroup from './BaseInputGroup'

const mergeProps = (...collections) => {
  return collections.reduce((props, collection) => {
    Object.keys(collection).forEach(key => {
      let prop = collection[key]
      let normalized = (prop.constructor === String)
        ? { default: prop }
        : prop
      if (key in props)
        props[key] = { ...props[key], ...normalized }
      else
        props[key] = normalized
    })
    return props
  }, {})
}

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
