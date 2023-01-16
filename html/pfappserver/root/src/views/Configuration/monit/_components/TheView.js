import {
  AlertServices,
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
import { useViewResource, useViewResourceProps as props } from '../../_composables/useViewResource'
import * as resource from '../_composables/useResource'

const setup = (props, context) => {

  const viewResource = useViewResource(resource, props, context)
  const {
    isLoading,
    isModified
  } = viewResource

  const scopedSlotProps = computed(() => ({ ...props, isLoading: isLoading.value, isModified: isModified.value }))

  return {
    ...viewResource,
    scopedSlotProps
  }
}

const render = renderHOCWithScopedSlots(BaseView, { components, props, setup }, {
  buttonsPrepend: AlertServices
})

// @vue/component
export default {
  name: 'the-view',
  extends: BaseView,
  inheritAttrs: false,
  props,
  render
}
