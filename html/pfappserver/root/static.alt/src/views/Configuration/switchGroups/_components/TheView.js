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
import { useViewCollectionItem, useViewCollectionItemProps as props } from '../../_composables/useViewCollectionItem'
import collection from '../_composables/useCollection'

const setup = (props, context) => {

  const {
    switchGroup
  } = toRefs(props)

  const viewCollectionItem = useViewCollectionItem(collection, props, context)
  const {
    form
  } = viewCollectionItem

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
