import {
  BaseView,

  FormButtonBar,
  TheForm
} from './'

const components = {
  FormButtonBar,
  TheForm
}

import { useViewCollectionItem, useViewCollectionItemProps } from '../../../_composables/useViewCollectionItem'
import collection, { useItemProps } from '../_composables/useCollection'

const props = {
  ...useViewCollectionItemProps,
  ...useItemProps
}

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
