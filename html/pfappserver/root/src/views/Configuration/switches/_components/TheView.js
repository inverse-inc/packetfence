import {
  BaseView,

  FormButtonBar,
  TheForm
} from './'

const components = {
  FormButtonBar,
  TheForm
}

import { computed, toRefs } from '@vue/composition-api'
import { usePropsWrapper } from '@/composables/useProps'
import { useViewCollectionItem, useViewCollectionItemProps } from '../../_composables/useViewCollectionItem'
import * as collection from '../_composables/useCollection'

const props = {
  ...useViewCollectionItemProps,
  ...collection.useItemProps
}

const setup = (props, context) => {
  const _collection = { ...collection } // unfurl Module
  // merge props w/ params in collection.useStore methods
  _collection.useStore = $store => usePropsWrapper(collection.useStore($store), props)

  const viewCollectionItem = useViewCollectionItem(_collection, props, context)
  const {
    form
  } = viewCollectionItem

  const {
    switchGroup
  } = toRefs(props)

  const titleBadge = computed(() => switchGroup.value || form.value.group)

  return {
    ...viewCollectionItem,

    titleBadge
  }
}

// @vue/component
export default {
  name: 'the-view',
  inheritAttrs: false,
  extends: BaseView,
  components,
  props,
  setup
}
