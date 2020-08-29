import BaseView, { props as baseProps } from '@/components/new/TheView'
import { mergeProps } from '@/components/new/utils'
import i18n from '@/utils/locale'
import {
  FormButtonBar,
  TheForm
} from './'

const components = {
  FormButtonBar,
  TheForm
}

const props = mergeProps(
  baseProps,
  {
    titleLabelisNone: id => i18n.t('Role {id}', { id }),
    titleLabelisClone: id => i18n.t('Clone Role {id}', { id }),
    titleLabelisNew: () => i18n.t('New Role')
  }
)

// @vue/component
export default {
  name: 'the-view',
  extends: BaseView,
  components,
  props
}
