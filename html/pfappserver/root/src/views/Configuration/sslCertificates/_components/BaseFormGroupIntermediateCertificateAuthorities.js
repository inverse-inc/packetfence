import { BaseFormGroupArray, BaseFormGroupArrayProps } from '@/components/new'
import BaseIntermediateCertificateAuthority from './BaseIntermediateCertificateAuthority'
import i18n from '@/utils/locale'

export const props = {
  ...BaseFormGroupArrayProps,

  buttonLabel: {
    type: String,
    default: i18n.t('Add Intermediate CA Certificate')
  },
  // overload :childComponent
  childComponent: {
    type: Object,
    default: () => BaseIntermediateCertificateAuthority
  },
  // overload :defaultItem
  defaultItem: {
    type: String
  }
}

export default {
  name: 'base-form-group-intermediate-certificate-authorities',
  extends: BaseFormGroupArray,
  props
}
