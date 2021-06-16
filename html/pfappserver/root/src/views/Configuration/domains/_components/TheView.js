import {
  BaseView,

  FormButtonBar,
  TheForm
} from './'

const components = {
  FormButtonBar,
  TheForm
}

import i18n from '@/utils/locale'
import { useViewCollectionItem, useViewCollectionItemProps } from '../../_composables/useViewCollectionItem'

const props = {
  ...useViewCollectionItemProps,

  actionKeyButtonVerb: {
    type: String,
    default: i18n.t('Join Domain')
  }
}

import * as collection from '../_composables/useCollection'

const setup = (props, context) => useViewCollectionItem(collection, props, context)

// @vue/component
export default {
  name: 'the-view',
  extends: BaseView,
  inheritAttrs: false,
  components,
  props,
  setup
}
