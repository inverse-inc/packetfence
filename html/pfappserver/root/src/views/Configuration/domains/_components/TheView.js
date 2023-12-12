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

const props = {
  ...useViewCollectionItemProps,

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
