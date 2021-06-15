import {
  BaseView,
  ButtonSamlMetaData,
  FormButtonBar,
  TheForm
} from './'

const components = {
  FormButtonBar,
  TheForm
}

import { computed, toRefs } from '@vue/composition-api'
import { usePropsWrapper } from '@/composables/useProps'
import { renderHOCWithScopedSlots } from '@/components/new/'
import { useViewCollectionItem, useViewCollectionItemProps } from '../../_composables/useViewCollectionItem'
import * as collection from '../_composables/useCollection'

const props = {
  ...useViewCollectionItemProps,
  ...collection.useItemProps
}

const setup = (props, context) => {

  const {
    sourceType
  } = toRefs(props)

  const _collection = { ...collection } // unfurl Module
  // merge props w/ params in collection.useStore methods
  _collection.useStore = $store => usePropsWrapper(collection.useStore($store), props)

  const viewCollectionItem = useViewCollectionItem(_collection, props, context)
  const {
    form
  } = viewCollectionItem

  const scopedSlotProps = computed(() => ({ ...props, sourceType: sourceType.value || form.value.type }))

  return {
    ...viewCollectionItem,

    scopedSlotProps
  }
}

const render = renderHOCWithScopedSlots(BaseView, { components, props, setup }, {
  buttonsAppend: ButtonSamlMetaData
})

// @vue/component
export default {
  name: 'the-view',
  inheritAttrs: false,
  props,
  render
}
