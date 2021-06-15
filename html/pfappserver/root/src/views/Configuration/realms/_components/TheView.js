import {
  BaseView,

  FormButtonBar,
  TheForm
} from './'

const components = {
  FormButtonBar,
  TheForm
}

import { usePropsWrapper } from '@/composables/useProps'
import { useViewCollectionItem, useViewCollectionItemProps } from '../../_composables/useViewCollectionItem'

const props = {
  ...useViewCollectionItemProps,

  tenantId: {
    type: [Number, String]
  }
}

import * as collection from '../_composables/useCollection'

const setup = (props, context) => {
  const _collection = { ...collection } // unfurl Module
  // merge props w/ params in collection.useStore methods
  _collection.useStore = $store => usePropsWrapper(collection.useStore($store), props)
  // merge props w/ params in collection.useRouter methods
  _collection.useRouter = $router => usePropsWrapper(collection.useRouter($router), props)

  return useViewCollectionItem(_collection, props, context)
}

// @vue/component
export default {
  name: 'the-view',
  extends: BaseView,
  inheritAttrs: false,
  components,
  props,
  setup
}
