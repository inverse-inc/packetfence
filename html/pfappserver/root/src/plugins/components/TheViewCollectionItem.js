/**
 * An item of a plugin page of the collection template: the core
 * BaseViewCollectionItem, its composables built from the manifest.
 */
import { BaseViewCollectionItem } from '@/views/Configuration/_components/new/'
import { BaseFormButtonBar } from '@/components/new/'
import { useViewCollectionItem, useViewCollectionItemProps } from '@/views/Configuration/_composables/useViewCollectionItem'
import TheForm from './TheForm'
import { usePlugin } from '../'
import { useCollection } from '../useView'
import { unavailable } from './unavailable'

const props = {
  ...useViewCollectionItemProps,
  pluginId: {
    type: String,
    required: true
  }
}

const setup = (props, context) => {
  const plugin = usePlugin(props.pluginId)
  return useViewCollectionItem((plugin) ? useCollection(plugin) : unavailable, props, context)
}

// @vue/component
export default {
  name: 'the-view-collection-item',
  extends: BaseViewCollectionItem,
  inheritAttrs: false,
  components: {
    FormButtonBar: BaseFormButtonBar,
    TheForm
  },
  props,
  setup
}
