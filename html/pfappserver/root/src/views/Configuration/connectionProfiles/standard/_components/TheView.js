import {
  ButtonPreviewPortal,
  BaseView,
  FormButtonBar,
  TheForm
} from './'

const components = {
  FormButtonBar,
  TheForm
}

import { computed } from '@vue/composition-api'
import { renderHOCWithScopedSlots } from '@/components/new/'
import { useViewCollectionItem, useViewCollectionItemProps } from '@/views/Configuration/_composables/useViewCollectionItem'
import * as collection from '../_composables/useCollection'

const props = {
  ...useViewCollectionItemProps,
  ...collection.useItemProps
}

const setup = (props, context) => {

  const viewCollectionItem = useViewCollectionItem(collection, props, context)
  const {
    isLoading,
    isModified
  } = viewCollectionItem

  const scopedSlotProps = computed(() => ({ ...props, isLoading: isLoading.value, isModified: isModified.value }))

  return {
    ...viewCollectionItem,
    scopedSlotProps
  }
}

const render = renderHOCWithScopedSlots(BaseView, { components, props, setup }, {
  headerAppend: ButtonPreviewPortal
})

// @vue/component
export default {
  name: 'the-view',
  extends: BaseView,
  inheritAttrs: false,
  props,
  render
}
