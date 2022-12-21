import {
  BaseView,
  FormButtonBar,
  TheForm
} from './'

const components = {
  FormButtonBar,
  TheForm
}

import { useViewCollectionItem, useViewCollectionItemProps } from '../../_composables/useViewCollectionItem'
import * as collection from '../_composables/useCollection'

const props = {
  ...useViewCollectionItemProps,
  ...collection.useItemProps
}

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
