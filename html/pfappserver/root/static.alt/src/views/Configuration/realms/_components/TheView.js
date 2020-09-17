import BaseView, { props } from '@/components/new/TheView'
import { useView } from '../_composables/useView'
import {
  FormButtonBar,
  TheForm
} from './'

const components = {
  FormButtonBar,
  TheForm
}

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
