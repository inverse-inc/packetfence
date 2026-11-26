<template>
  <base-step ref="rootRef"
    :name="$t('Confirmation')"
    icon="check"
    :invalid-feedback="invalidFeedback"
    :progress-feedback="progressFeedback"
    :is-loading="isLoading"
    >
    <form-status ref="statusRef" />
    <template v-slot:button-next>
      <base-button-save :isLoading="isLoading" variant="primary" @click="onComplete">
        {{ $i18n.t('Start PacketFence') }} <icon class="ml-1" name="play"></icon>
      </base-button-save>
    </template>
  </base-step>
</template>
<script>
import i18n from '@/utils/locale'
import { BaseButtonSave } from '@/components/new/'
import BaseStep from '../../_components/BaseStep'
import FormStatus from './FormStatus'

const components = {
  BaseButtonSave,
  BaseStep,
  FormStatus
}

import { ref } from '@vue/composition-api'

const setup = (props, context) => {

  const { root: { $store } = {} } = context

  const rootRef = ref(null)
  const isLoading = ref(false)

  const invalidFeedback = ref(null)
  const progressFeedback = ref(null)

  const onComplete = async () => {
    isLoading.value = true
    invalidFeedback.value = null
    progressFeedback.value = i18n.t('Applying configuration')
    let errorMessage = i18n.t('Failed to restart packetfence-config')
    try {
      await $store.dispatch('cluster/restartSystemService', { id: 'packetfence-config' })

      progressFeedback.value = i18n.t('Enabling PacketFence')
      errorMessage = i18n.t('Failed to update systemd')
      await $store.dispatch('cluster/updateSystemd', { id: 'pf' })

      progressFeedback.value = i18n.t('Starting PacketFence')
      errorMessage = i18n.t('Failed to restart pfperl-api')
      await $store.dispatch('cluster/restartService', { id: 'pfperl-api' })
      errorMessage = i18n.t('Failed to restart haproxy-admin')
      await $store.dispatch('cluster/restartService', { id: 'haproxy-admin' })
      errorMessage = i18n.t('Failed to start packetfence services')
      await $store.dispatch('cluster/startService', { id: 'pf' })

      progressFeedback.value = i18n.t('Disabling Configurator')
      errorMessage = i18n.t('Failed to complete configuration')
      await $store.dispatch('cluster/completeConfigurator')
      progressFeedback.value = i18n.t('Redirecting to login page')
      setTimeout(() => {
        window.location.href = '/'
      }, 2000)
    } catch (err) {
      invalidFeedback.value = errorMessage
      progressFeedback.value = null
    } finally {
      isLoading.value = false
    }
  }

  return {
    rootRef,
    isLoading,
    invalidFeedback,
    progressFeedback,
    onComplete
  }
}


// @vue/component
export default {
  name: 'the-step',
  components,
  setup
}
</script>
