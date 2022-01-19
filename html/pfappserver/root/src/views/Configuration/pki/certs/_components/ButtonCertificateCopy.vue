<template>
  <b-button v-if="!isClone && !isNew"
    size="sm" variant="outline-primary" class="text-nowrap"
    :disabled="disabled"
    @click.stop.prevent="onClipboard"
  >{{ $t('Copy Certificate') }}</b-button>
</template>
<script>
const props = {
  id : {
    type: [String, Number]
  },
  isClone: {
    type: Boolean
  },
  isNew: {
    type: Boolean
  },
  disabled: {
    type: Boolean
  }
}

import { toRefs } from '@vue/composition-api'
import i18n from '@/utils/locale'

const setup = (props, context) => {

  const {
    id
  } = toRefs(props)

  const { root: { $store } = {} } = context

  const onClipboard = () => {
    $store.dispatch('$_pkis/getCert', id.value).then(cert => {
      try {
        navigator.clipboard.writeText(cert.cert).then(() => {
          $store.dispatch('notification/info', { message: i18n.t('<code>{cn}</code> certificate copied to clipboard', cert) })
        }).catch(() => {
          $store.dispatch('notification/danger', { message: i18n.t('Could not copy <code>{cn}</code> certificate to clipboard.', cert) })
        })
      } catch (e) {
        $store.dispatch('notification/danger', { message: i18n.t('Clipboard not supported.') })
      }
    })
  }

  return {
    onClipboard
  }
}

// @vue/component
export default {
  name: 'button-certificate-copy',
  inheritAttrs: false,
  props,
  setup
}
</script>
