import {
  BaseFormGroupFileUpload, BaseFormGroupFileUploadProps,
  BaseFormGroupInput, BaseFormGroupInputProps
} from '@/components/new'

export const props = {
  ...BaseFormGroupInputProps,
  ...BaseFormGroupFileUploadProps,

  // overload :childComponent
  component: {
    type: Object,
    default: () => BaseFormGroupInput
  },
}

export default {
  name: 'base-form-group-path-file-upload',
  extends: BaseFormGroupFileUpload,
  props
}
