<template>
  <base-step ref="rootRef"
    :name="$t('Confirmation')"
    icon="check">
    <form-status ref="statusRef" />
    <template v-slot:button-next>
      <base-button-save :isLoading="isLoading" variant="primary" @click="onComplete">
        {{ $i18n.t('Start PacketFence') }} <icon class="ml-1" name="play"></icon>
      </base-button-save>

      <div v-if="invalidFeedback && !isLoading"
       class="d-block invalid-feedback" v-text="invalidFeedback"></div>

      <div v-else-if="progressFeedback"
        class="d-block valid-feedback" v-text="progressFeedback"></div>
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

  const { root: { $router, $store } = {} } = context

  const rootRef = ref(null)
  const isLoading = ref(false)

  const invalidFeedback = ref(undefined)
  const progressFeedback = ref(undefined)

  const advancedPromise = $store.dispatch('$_bases/getAdvanced') // prefetch advanced configuration

  const onComplete = () => {
    isLoading.value = true
    progressFeedback.value = i18n.t('Applying configuration')
    $store.dispatch('services/restartSystemService', 'packetfence-config')
      .then(() => {
        progressFeedback.value = i18n.t('Enabling PacketFence')
        return $store.dispatch('services/updateSystemd', 'pf').then(() => {
          progressFeedback.value = i18n.t('Starting PacketFence')
          return $store.dispatch('services/restartService', { quiet: true, id: 'haproxy-admin' })
            .catch(e => e)
            .finally(() => {
              const haproxyReady = new Promise((resolve, reject) => {
                let count = 10 // try to reconnect at most 10 times
                const pingHaproxy = () => {
                  $store.dispatch('system/getHostname', { cache: false })
                    .then(resolve)
                    .catch(() => {
                      count--
                      if (count > 0) {
                        setTimeout(pingHaproxy, 2000)
                      } else {
                        reject()
                      }
                    })
                }
                pingHaproxy()
              })
              return haproxyReady.then(() => {
                return $store.dispatch('services/startService', 'pf').then(() => {
                  progressFeedback.value = i18n.t('Disabling Configurator')
                  return advancedPromise.then(data => {
                    data.configurator = 'disabled'
                    return $store.dispatch('$_bases/updateAdvanced', data).then(() => {
                      progressFeedback.value = i18n.t('Redirecting to login page')
                      setTimeout(() => {
                        $router.push({ name: 'login' })
                      }, 2000)
                    })
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
