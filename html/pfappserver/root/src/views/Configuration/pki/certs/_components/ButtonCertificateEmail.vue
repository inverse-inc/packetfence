<template>
  <b-button v-if="!isClone && !isNew"
    size="sm" variant="outline-primary" :disabled="isLoading" @click.stop.prevent="onEmail">{{ $t('Email') }}</b-button>
</template>
<script>
import {
  BaseForm,
  BaseFormGroupChosenOne as FormGroupReason
} from '@/components/new/'

const components = {
  BaseForm,
  FormGroupReason
}

const props = {
  id : {
    type: [String, Number]
  },
  isClone: {
    type: Boolean
  },
  isNew: {
    type: Boolean
  }
}

import { computed, toRefs } from '@vue/composition-api'
import i18n from '@/utils/locale'
import StoreModule from '../../_store'

const setup = (props, context) => {

  const {
    id
  } = toRefs(props)

  const { root: { $store } = {} } = context

  if (!$store.state.$_pkis)
    $store.registerModule('$_pkis', StoreModule)

  const isLoading = computed(() => $store.getters['$_pkis/isLoading'])
  const onEmail = () => {
    $store.dispatch('$_pkis/getCert', id.value).then(cert => {
      const { ID, cn, mail } = cert
      $store.dispatch('$_pkis/emailCert', ID).then(() => {
        $store.dispatch('notification/info', { message: i18n.t('Certificate <code>{cn}</code> emailed to <code>{mail}</code>.', { cn, mail }) })
      }).catch(e => {
        $store.dispatch('notification/danger', { message: i18n.t('Could not email certificate <code>{cn}</code> to <code>{mail}</code>: ', { cn, mail }) + e })
      })
    })
  }

  return {
    isLoading,
    onEmail
  }
}

// @vue/component
export default {
  name: 'button-certificate-email',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
