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
import collection, { useItemProps, useItemTitleBadge } from '../_composables/useCollection'

const props = {
  ...useViewCollectionItemProps,
  ...useItemProps
}

const setup = (props, context) => {

  const viewCollectionItem = useViewCollectionItem(collection, props, context)

  const titleBadge = useItemTitleBadge(props)

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
