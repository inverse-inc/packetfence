import {
  BaseView,
  ButtonServiceKafka,

  FormButtonBar,
  TheForm
} from './'

const components = {
  FormButtonBar,
  TheForm
}

import { renderHOCWithScopedSlots } from '@/components/new/'
import { useViewResource, useViewResourceProps as props } from '../../_composables/useViewResource'

import * as resource from '../_composables/useResource'
const setup = (props, context) => useViewResource(resource, props, context)

const render = renderHOCWithScopedSlots(BaseView, { components, props, setup }, {
  headerAppend: ButtonServiceKafka
})

// @vue/component
export default {
  name: 'the-view',
  extends: BaseView,
  inheritAttrs: false,
  props,
  render
}
