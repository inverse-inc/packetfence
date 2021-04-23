import { BaseInputGroupTextareaUpload, BaseInputGroupTextareaUploadProps } from '@/components/new/'
import i18n from '@/utils/locale'

export const props = {
  ...BaseInputGroupTextareaUploadProps,

  // overload :tooltip default
  tooltip: {
    type: String,
    default: i18n.t('Click or drag-and-drop to upload a certificate')
  },

  // auto-fit textarea contents
  autoFit: {
    type: Boolean,
    default: true
  }
}

export default {
  name: 'base-intermediate-certificate-authority',
  extends: BaseInputGroupTextareaUpload,
  props
}
