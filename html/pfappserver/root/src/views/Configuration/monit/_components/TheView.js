import {
  BaseView,

  FormButtonBar,
  TheForm
} from './'

const components = {
  FormButtonBar,
  TheForm
}

import { useViewResource, useViewResourceProps as props } from '../../_composables/useViewResource'

import * as resource from '../_composables/useResource'
const setup = (props, context) => useViewResource(resource, props, context)

// @vue/component
export default {
  name: 'the-view',
  extends: BaseView,
  inheritAttrs: false,
  components,
  props,
  setup
}

