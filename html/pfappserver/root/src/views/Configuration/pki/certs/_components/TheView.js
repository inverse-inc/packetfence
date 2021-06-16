import {
  BaseView,
  ButtonCertificateDownload,
  ButtonCertificateEmail,
  ButtonCertificateRevoke,
  FormButtonBar,
  TheForm
} from './'

const components = {
  FormButtonBar,
  TheForm
}

import { renderHOCWithScopedSlots } from '@/components/new/'
import { useViewCollectionItem, useViewCollectionItemProps } from '../../../_composables/useViewCollectionItem'
import * as collection from '../_composables/useCollection'

const props = {
  ...useViewCollectionItemProps,
  ...collection.useItemProps
}

const setup = (props, context) => {
  const viewCollectionItem = useViewCollectionItem(collection, props, context)
  return {
    ...viewCollectionItem,
    scopedSlotProps: props
  }
}

import { BButtonGroup } from 'bootstrap-vue'

const render = renderHOCWithScopedSlots(BaseView, { components, props, setup }, {
  buttonsAppend: (h, props) => {
    return h(BButtonGroup, {}, [
      h(ButtonCertificateDownload, { props }),
      h(ButtonCertificateEmail, { props }),
      h(ButtonCertificateRevoke, { props })
    ])
  }
})

// @vue/component
export default {
  name: 'the-view',
  inheritAttrs: false,
  props,
  render
}
