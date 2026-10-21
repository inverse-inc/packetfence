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

  const advancedPromise = $store.dispatch('$_bases/getAdvanced') // prefetch advanced configuration

  const catchWithError = message => {
    return () => {
      isLoading.value = false
      invalidFeedback.value = message
      progressFeedback.value = null
    }
  }

  const onComplete = () => {
    isLoading.value = true
    invalidFeedback.value = null
    progressFeedback.value = i18n.t('Applying configuration')
    $store.dispatch('cluster/restartSystemService', { id: 'packetfence-config' }).catch(catchWithError(i18n.t('Failed to restart packetfence-config'))).then(() => {
      invalidFeedback.value = null
      progressFeedback.value = i18n.t('Enabling PacketFence')
      return $store.dispatch('cluster/updateSystemd', { id: 'pf' }).catch(catchWithError(i18n.t('Failed to update systemd'))).then(() => {
        invalidFeedback.value = null
        progressFeedback.value = i18n.t('Starting PacketFence')
        return $store.dispatch('cluster/restartService', { id: 'pfperl-api' }).catch(catchWithError(i18n.t('Failed to restart pfperl-api'))).then(() => {
          invalidFeedback.value = null
          return $store.dispatch('cluster/restartService', { id: 'haproxy-admin' }).catch(catchWithError(i18n.t('Failed to restart haproxy-admin'))).then(() => {
            invalidFeedback.value = null
            return $store.dispatch('cluster/startService', { id: 'pf' }).catch(catchWithError(i18n.t('Failed to start packetfence services'))).then(() => {
              invalidFeedback.value = null
              progressFeedback.value = i18n.t('Disabling Configurator')
              return advancedPromise.then(data => {
                data.configurator = 'disabled'
                return $store.dispatch('$_bases/updateAdvanced', data).catch(catchWithError(i18n.t('Failed to update advanced'))).then(() => {
                  invalidFeedback.value = null
                  progressFeedback.value = i18n.t('Redirecting to login page')
                  setTimeout(() => {
                    window.location.href = '/'
                  }, 2000)
                })
              })
            })
          })
        })
      })
      .finally(() => {
        isLoading.value = false
      })
    })
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
