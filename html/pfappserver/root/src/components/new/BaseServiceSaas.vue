<template>
  <b-container fluid>
    <b-progress :max="service.total_replicas" height="2em" :animated="service.updated_replicas !== service.total_replicas">
      <b-progress-bar :value="service.updated_replicas" :precision="2" variant="success" :show-value="false"></b-progress-bar>
      <b-progress-bar :value="service.total_replicas - service.updated_replicas" :precision="2" variant="warning" :show-value="false" striped></b-progress-bar>
    </b-progress>
    <small>{{ service.updated_replicas }}/{{ service.total_replicas }} {{ $i18n.t('Replicas') }}</small>

    <b-button v-if="isAllowed && restart"
      @click="doRestart" :disabled="isLoading" variant="link" size="sm" class="text-nowrap text-secondary">
      <icon name="redo" class="mt-3 mr-1" /> {{ $i18n.t('Restart') }}
    </b-button>

    <b-row v-if="message"
      class="mt-3 mx-0">
      <b-col cols="12" class="small text-danger text-wrap">
        <icon name="info-circle" scale="1.5" class="mr-1" /> {{ message }}
      </b-col>
    </b-row>
  </b-container>
</template>
<script>
const props = {
  id: {
    type: String
  },
  restart: {
    type: Boolean
  },
  acl: {
    type: String,
    default: 'SERVICES_READ'
  },
  lazy: {
    type: Boolean
  }
}

import { computed, toRefs, watch } from '@vue/composition-api'
import acl from '@/utils/acl'
import i18n from '@/utils/locale'
import { localeStrings } from '@/globals/pfLocales'

const setup = (props, context) => {

  const {
    id,
    lazy,
    acl: _acl
  } = toRefs(props)

  const { emit, root: { $store } = {} } = context

  const isAllowed = computed(() => {
    if (_acl.value) {
      const [ verb, ...nouns ] = Array.prototype.slice.call(_acl.value.toLowerCase().split('_')).reverse()
      const noun = nouns.reverse().join('_')
      return verb && nouns.length > 0 && acl.$can(verb, noun)
    }
    return true
  })

  watch([id], () => {
    if (id.value && isAllowed.value && !lazy.value) {
      $store.dispatch('k8s/getService', id.value)
    }
  }, { immediate: true })

  const isLoading = computed(() => $store.getters['k8s/isLoading'])
  const message = computed(() => $store.state.k8s.message)
  const services = computed(() => $store.state.k8s.services)
  const service = computed(() => ({ total_replicas: 0, updates_replicas: 0, ...services.value[id.value] }))

  const doRestart = () => $store.dispatch('k8s/restartService', id.value).then(() => {
    $store.dispatch('notification/info', { url: id.value, message: i18n.t(localeStrings.SERVICES_K8S_RESTARTED_SUCCESS, { services: `<code>${id.value}</code>` }) })
    emit('restart', id.value)
  }).catch(() => {
    const message = i18n.t(localeStrings.SERVICES_K8S_RESTARTED_ERROR, { services: `<code>${id.value}</code>` })
    $store.dispatch('notification/danger', { url: id.value, message })
  })

  return {
    message,
    service,

    isAllowed,
    isLoading,

    doRestart,
  }
}

// @vue/component
export default {
  name: 'base-service-saas',
  props,
  setup
}
</script>
