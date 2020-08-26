import { BaseFormGroupInput, BaseFormGroupInputProps, mergeProps } from '@/components/new/'
import i18n from '@/utils/locale'

// @vue/component
export default {
  name: 'form-group-max-nodes-per-pid',
  extends: BaseFormGroupInput,
  inheritAttrs: false,
  props: mergeProps(
    BaseFormGroupInputProps,
    {
      columnLabel: i18n.t('Max nodes per user'),
      text: i18n.t('The maximum number of nodes a user having this role can register. A number of 0 means unlimited number of devices.'),
      type: 'number'
    }
  )
}
