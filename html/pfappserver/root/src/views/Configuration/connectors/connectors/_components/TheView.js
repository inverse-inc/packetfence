import {
  BaseView,

  FormButtonBar,
  TheForm,
  TheHeader
} from './'

const components = {
  ...useViewCollectionItemComponents,
  FormButtonBar,
  TheForm
}

import { computed, provide } from '@vue/composition-api'
import { renderHOCWithScopedSlots } from '@/components/new/'
import {
  useViewCollectionItem,
  useViewCollectionItemComponents,
  useViewCollectionItemProps as props
} from '../../../_composables/useViewCollectionItem'
import * as collection from '../_composables/useCollection'
import { useRemoteStatus } from '../_composables/useRemoteStatus'
import { useTabs } from '../_composables/useTabs'

const setup = (props, context) => {

  const viewCollectionItem = useViewCollectionItem(collection, props, context)
  const {
    isCloneable: _isCloneable,
    isDeletable: _isDeletable,
    isSaveable: _isSaveable
  } = viewCollectionItem

  // live state of the connector-remote, shared with the header and the tabs
  const remote = useRemoteStatus(props, context)
  provide('connectorRemote', remote)

  const tabs = useTabs(props, context, remote)
  provide('connectorTabs', tabs)

  // the form buttons only apply to the Settings tab
  const { isSettings } = tabs
  const isSaveable = computed(() => isSettings.value && _isSaveable.value)
  const isCloneable = computed(() => isSettings.value && _isCloneable.value)
  const isDeletable = computed(() => isSettings.value && _isDeletable.value)

  return {
    ...viewCollectionItem,
    isSaveable,
    isCloneable,
    isDeletable
  }
}

const render = renderHOCWithScopedSlots(BaseView, { components, props, setup }, {
  headerAppend: TheHeader
})

// @vue/component
export default {
  name: 'the-view',
  extends: BaseView,
  inheritAttrs: false,
  props,
  render
}
