import BaseView from '@/components/new/TheView'
import { useView, useViewProps } from '../_composables/useView'
import {
  FormButtonBar,
  TheForm
} from './'

const components = {
  FormButtonBar,
  TheForm
}

const props = useViewProps

const render = BaseView.render

const setup = (props, context) => useView(props, context)

// @vue/component
export default {
  name: 'the-view',
  inheritAttrs: false,
  components,
  props,
  render,
  setup
}
