import { BaseFormGroupTextareaUpload, BaseFormGroupTextareaUploadProps } from '@/components/new/'
import i18n from '@/utils/locale'

export const props = {
  ...BaseFormGroupTextareaUploadProps,

  // overload :tooltip default
  tooltip: {
    type: String,
    default: i18n.t('Click or drag-and-drop to upload a certificate')
  }
}

export default {
  name: 'base-form-group-certificate',
  extends: BaseFormGroupTextareaUpload,
  props
}
