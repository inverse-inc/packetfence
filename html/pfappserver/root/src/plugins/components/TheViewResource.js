/**
 * A plugin page of the resource template: the core BaseViewResource, its
 * composables built from the manifest.
 */
import { BaseViewResource } from '@/views/Configuration/_components/new/'
import { BaseFormButtonBar } from '@/components/new/'
import { useViewResource, useViewResourceProps } from '@/views/Configuration/_composables/useViewResource'
import TheForm from './TheForm'
import { usePlugin } from '../'
import { useResource } from '../useView'
import { unavailable } from './unavailable'

const props = {
  ...useViewResourceProps,
  pluginId: {
    type: String,
    required: true
  }
}

const setup = (props, context) => {
  const plugin = usePlugin(props.pluginId)
  return useViewResource((plugin) ? useResource(plugin) : unavailable, props, context)
}

// @vue/component
export default {
  name: 'the-view-resource',
  extends: BaseViewResource,
  inheritAttrs: false,
  components: {
    FormButtonBar: BaseFormButtonBar,
    TheForm
  },
  props,
  setup
}
