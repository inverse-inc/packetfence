import { BaseViewCollectionItem as BaseView } from '../../_components/new/'
import { BaseFormButtonBar as FormButtonBar } from '@/components/new/'
import TheForm from './TheForm'

const components = {
  FormButtonBar,
  TheForm
}

import { useViewCollectionItem, useViewCollectionItemProps } from '../../_composables/useViewCollectionItem'
import { useCollection, useItemProps } from '../_composables/useCollection'

const props = {
  ...useViewCollectionItemProps,
  ...useItemProps
}

const setup = (props, context) => useViewCollectionItem(useCollection(props), props, context)

// @vue/component
export default {
  name: 'the-view',
  inheritAttrs: false,
  extends: BaseView,
  components,
  props,
  setup
}
