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

  const onComplete = () => {
    isLoading.value = true
    progressFeedback.value = i18n.t('Applying configuration')
    $store.dispatch('cluster/restartSystemService', { id: 'packetfence-config' }).then(() => {
      progressFeedback.value = i18n.t('Enabling PacketFence')
      return $store.dispatch('cluster/updateSystemd', { id: 'pf' }).then(() => {
        progressFeedback.value = i18n.t('Starting PacketFence')
        return $store.dispatch('cluster/restartService', { id: 'pfperl-api' }).then(() => {
          return $store.dispatch('cluster/restartService', { id: 'haproxy-admin' }).then(() => {
            return $store.dispatch('cluster/startService', { id: 'pf' }).then(() => {
              progressFeedback.value = i18n.t('Disabling Configurator')
              return advancedPromise.then(data => {
                data.configurator = 'disabled'
                return $store.dispatch('$_bases/updateAdvanced', data).then(() => {
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
      .catch(() => {
        progressFeedback.value = null
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
