<template>
  <b-dropdown ref="buttonRef"
    :disabled="isDisabled"
    :size="size"
    :text="service"
    no-flip
    :variant="(available) ? 'outline-primary' : 'outline-secondary'"
    v-b-tooltip.hover.top.d300 :title="tooltip"
    v-bind="$attrs"
  >
    <template v-slot:button-content>
      <div class="d-inline px-1">
        <template v-for="(replica, index) in replicas">
          <icon :key="`icon-${index}`"
            name="circle" :class="(replica) ? 'text-success' : 'text-warning'" class="fa-overlap mr-1" />
        </template>
        {{ service }}
      </div>
    </template>
    <template v-slot:default>
      <base-service-saas :id="service" v-bind="{ acl, restart }" />
    </template>
  </b-dropdown>
</template>
<script>
import BaseServiceSaas from './BaseServiceSaas'

const components = {
  BaseServiceSaas
}

import { computed, nextTick, ref, toRefs, watch } from '@vue/composition-api'
import acl from '@/utils/acl'
import i18n from '@/utils/locale'
import { localeStrings } from '@/globals/pfLocales'

const props = {
  service: {
    type: String
  },
  restart: {
    type: Boolean
  },
  size: {
    type: String,
    default: 'md',
    validator: value => ['sm', 'md', 'lg'].includes(value)
  },
  disabled: {
    type: Boolean
  },
  acl: {
    type: String,
    default: 'SERVICES_READ'
  }
}

const setup = (props, context) => {

  const buttonRef = ref(null)

  const onClick = event => {
    event.stopPropagation()
    nextTick(() => {
      buttonRef.value.show() // keep open on click
    })
  }

  const {
    service,
    disabled,
    acl: _acl
  } = toRefs(props)

  const { root: { $store } = {}, emit } = context

  const isAllowed = computed(() => {
    if (_acl.value) {
      const [ verb, ...nouns ] = Array.prototype.slice.call(_acl.value.toLowerCase().split('_')).reverse()
      const noun = nouns.reverse().join('_')
      return verb && nouns.length > 0 && acl.$can(verb, noun)
    }
    return true
  })

  watch(service, () => {
    if (isAllowed.value) {
      $store.dispatch('k8s/getService', service.value)
    }
  }, { immediate: true })
  const isLoading = computed(() => $store.getters['k8s/isLoading'])
  const isDisabled = computed(() => disabled.value || !isAllowed.value)
  const available = computed(() => {
    const { [service.value]: { available } = {} } = $store.state.k8s.services
    return available
  })
  const replicas = computed(() => {
    const { [service.value]: { total_replicas, updated_replicas } = {} } = $store.state.k8s.services
     
    return [ ...Array(total_replicas) ].map((_, i) => (i < updated_replicas))
  })

  const tooltip = computed(() => {
    switch (true) {
      case !isAllowed.value:
        return i18n.t('No permission, admin role {acl} required.', { acl: _acl.value })
        //break

      default:
        return undefined
    }
  })

  const doRestart = server => $store.dispatch('k8s/restartService', service.value).then(() => {
    $store.dispatch('notification/info', { url: server, message: i18n.t(localeStrings.K8S_SERVICES_RESTARTED_SUCCESS, { services: `<code>${service.value}</code>` }) })
    emit('restart', service.value)
  }).catch(() => {
    $store.dispatch('notification/danger', { url: server, message: i18n.t(localeStrings.K8S_SERVICES_RESTARTED_ERROR, { services: `<code>${service.value}</code>` }) })
  })

  return {
    available,
    replicas,

    buttonRef,
    onClick,

    isAllowed,
    isDisabled,
    isLoading,
    tooltip,

    doRestart,
  }
}

// @vue/component
export default {
  name: 'base-button-service-saas',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
