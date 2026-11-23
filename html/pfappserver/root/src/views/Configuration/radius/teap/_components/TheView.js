import {
  BaseView,
  FormButtonBar,
  TheForm
} from './'

const components = {
  FormButtonBar,
  TheForm
}

import { useViewCollectionItem, useViewCollectionItemProps as props } from '../../../_composables/useViewCollectionItem'
import * as collection from '../_composables/useCollection'

const setup = (props, context) => useViewCollectionItem(collection, props, context)

// @vue/component
export default {
  name: 'the-view',
  inheritAttrs: false,
  extends: BaseView,
  components,
  props,
  setup
}
