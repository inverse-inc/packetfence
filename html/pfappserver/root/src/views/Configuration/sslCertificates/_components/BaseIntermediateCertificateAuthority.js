import { BaseInputGroupTextareaUpload, BaseInputGroupTextareaUploadProps } from '@/components/new/'
import i18n from '@/utils/locale'

export const props = {
  ...BaseInputGroupTextareaUploadProps,

  // overload :accept default
  accept: {
    type: String,
    default: 'application/x-x509-ca-cert, application/vnd.apple.keynote, text/*'
  },

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
