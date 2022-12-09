<template>
  <b-overlay :show="service.status && !['success', 'error'].includes(service.status)" variant="white">
    <b-container fluid class="px-0">
      <b-row class="row-nowrap mx-0" align-v="center">
        <b-col cols="5" class="text-wrap" v-if="isAllowed">
          <b-button
            @click="doUpdate(server)" :disabled="isLoading" variant="link" size="sm" class="text-nowrap text-secondary mr-1">
            <icon name="sync" class="mr-1" /> {{ $i18n.t('Update') }}
          </b-button>
        </b-col>
      </b-row>
      <b-row v-if="service.message"
        class="mt-2 mx-0">
        <b-col cols="auto" class="small text-danger text-wrap">
          <icon name="info-circle" scale="1.5" class="mr-1" /> {{ service.message }}
        </b-col>
      </b-row>
    </b-container>
    <template v-slot:overlay v-if="service.status && service.status !== 'loading'">
      <b-row class="justify-content-md-center">
        <b-col cols="auto">
          <b-media class="text-gray text-uppercase font-weight-bold">
            <template v-slot:aside><icon name="circle-notch" spin scale="1.5" /></template>
            <p v-if="service.status === 'updating'" class="mb-0">{{ $i18n.t('Updating') }}</p>
          </b-media>
        </b-col>
      </b-row>
    </template>
  </b-overlay>
</template>
<script>
const props = {
  id: {
    type: String
  },
  server: {
    type: String
  },
  acl: {
    type: String,
    default: 'SERVICES_UPDATE'
  },
}

import { computed, toRefs } from '@vue/composition-api'
import acl from '@/utils/acl'
import i18n from '@/utils/locale'
import { localeStrings } from '@/globals/pfLocales'

const setup = (props, context) => {

  const {
    id,
    server,
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

  const service = computed(() => $store.state.cluster.servers[server.value].systemd[id.value] || {})
  const isLoading = computed(() => $store.getters['cluster/isLoading'])

  const doUpdate = () => $store.dispatch('cluster/updateSystemd', { server: server.value, id: id.value }).then(() => {
    $store.dispatch('notification/info', { url: server.value, message: i18n.t(localeStrings.SYSTEMD_UPDATED_SUCCESS, { service: `<code>${id.value}</code>` }) })
    emit('update', { server, id: id.value })
  }).catch(() => {
    const message = i18n.t(localeStrings.SYSTEMD_UPDATED_ERROR, { services: `<code>${id.value}</code>` })
    $store.dispatch('notification/danger', { url: server.value, message })
  })

  return {
    service,

    isAllowed,
    isLoading,

    doUpdate,
  }
}

// @vue/component
export default {
  name: 'base-systemd-update',
  props,
  setup
}
</script>
