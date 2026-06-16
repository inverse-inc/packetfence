<template>
  <b-button :size="size" variant="outline-primary"
    :disabled="isDisabled"
    @click="onGenerate">
    <icon v-if="isLoading" class="mr-1" name="circle-notch" spin /> {{ $t('Generate Certificate') }}
  </b-button>
</template>
<script>
const props = {
  form: {
    type: Object
  },
  disabled: {
    type: Boolean
  },
  size: {
    type: String,
    default: 'md',
    validator: value => ['sm', 'md', 'lg'].includes(value)
  }
}

import i18n from '@/utils/locale'
import { computed } from '@vue/composition-api'

const setup = (props, context) => {

  const { root: { $store } = {} } = context

  const isLoading = computed(() => $store.getters['$_kafka/isLoading'])

  const ssl = computed(() => (props.form || {}).ssl || {})

  const isDisabled = computed(() => {
    const { ca_id, cn } = ssl.value
    return props.disabled || isLoading.value || !ca_id || !cn
  })

  const onGenerate = () => {
    const { ca_id, cn, dns_names, ip_addresses } = ssl.value
    $store.dispatch('$_kafka/generateCert', { ca_id, cn, dns_names, ip_addresses }).then(response => {
      const { serial, valid_until } = response || {}
      $store.dispatch('notification/info', {
        message: i18n.t('Kafka certificate generated (serial {serial}, valid until {validUntil}). Save and restart kafka to apply.', { serial: serial || '-', validUntil: valid_until || '-' })
      })
    }).catch(() => {
      const message = $store.state.$_kafka.message
      $store.dispatch('notification/danger', {
        message: i18n.t('Failed to generate the Kafka certificate. {message}', { message: message || '' })
      })
    })
  }

  return {
    isLoading,
    isDisabled,
    onGenerate
  }
}

// @vue/component
export default {
  name: 'button-kafka-generate-cert',
  inheritAttrs: false,
  props,
  setup
}
</script>
