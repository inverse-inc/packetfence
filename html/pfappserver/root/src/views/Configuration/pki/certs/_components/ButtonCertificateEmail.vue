<template>
  <b-button v-if="!isClone && !isNew && !isScep && !isCsr"
    size="sm" variant="outline-primary" :disabled="disabled || isLoading" @click.stop.prevent="onEmail">{{ $t('Email') }}</b-button>
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
  },
  disabled: {
    type: Boolean
  }
}

import { computed, ref, toRefs, watch } from '@vue/composition-api'
import i18n from '@/utils/locale'
import StoreModule from '../../_store'

const setup = (props, context) => {

  const {
    id
  } = toRefs(props)

  const { root: { $store } = {} } = context

  if (!$store.state.$_pkis)
    $store.registerModule('$_pkis', StoreModule)

  const cert = ref({})
  watch(id, () => {
    if(!id.value) {
      cert.value = {}
    }
    else {
      $store.dispatch('$_pkis/getCert', id.value)
        .then(_cert => cert.value = _cert)
    }
  }, { immediate: true })
  const isScep = computed(() => {
    const { scep } = cert.value
    return scep
  })
  const isCsr = computed(() => {
    const { csr } = cert.value
    return csr
  })
  const isLoading = computed(() => $store.getters['$_pkis/isLoading'])
  const onEmail = () => {
    const { id, cn, mail } = cert.value
    $store.dispatch('$_pkis/emailCert', id).then(() => {
      $store.dispatch('notification/info', { message: i18n.t('Certificate <code>{cn}</code> emailed to <code>{mail}</code>.', { cn, mail }) })
    }).catch(e => {
      $store.dispatch('notification/danger', { message: i18n.t('Could not email certificate <code>{cn}</code> to <code>{mail}</code>: ', { cn, mail }) + e })
    })
  }

  return {
    isLoading,
    isScep,
    isCsr,
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
