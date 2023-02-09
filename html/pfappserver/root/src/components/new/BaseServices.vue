<template>
  <b-alert :show="show" :variant="variant" dismissible fade>
    <h4 v-if="title"
      class="alert-heading" v-t="title"/>
    <p v-html="message" />
    <template v-if="isSaas">
      <base-button-service-saas v-for="service in k8sServicesSorted" :key="`k8s-service-${service}`"
        :service="service" restart
        class="mr-1" :size="size" />
    </template>
    <template v-else>
      <base-button-service v-for="service in servicesSorted" :key="`service-${service}`"
        :service="service" restart start stop
        class="mr-1" :size="size" />
      <base-button-service-system v-for="service in systemServicesSorted" :key="`system-service-${service}`"
        :service="service" restart start stop
        class="mr-1" :size="size" />
      <base-button-systemd-update v-if="systemd"
        class="ml-1" />
    </template>
  </b-alert>
</template>
<script>
import {
  BaseButtonService,
  BaseButtonServiceSaas,
  BaseButtonServiceSystem,
  BaseButtonSystemdUpdate,
} from '@/components/new/'
const components = {
  BaseButtonService,
  BaseButtonServiceSaas,
  BaseButtonServiceSystem,
  BaseButtonSystemdUpdate,
}

import i18n from '@/utils/locale'
const props = {
  title: {
    type: String
  },
  message: {
    type: String,
    default: i18n.t('Some services must be restarted to load the new settings.')
  },
  size: {
    type: String,
    default: 'md'
  },
  variant: {
    type: String,
    default: 'warning'
  },
  services: {
    type: Array,
    default: () => ([])
  },
  system_services: {
    type: Array,
    default: () => ([])
  },
  systemd: {
    type: Boolean
  },
  k8s_services: {
    type: Array,
    default: () => ([])
  },
  acl: {
    type: String,
    default: 'SERVICES_READ'
  },
  value: {
    type: [Boolean, Number, String],
    default: true
  }
}

import { computed, toRefs } from '@vue/composition-api'

const setup = (props, context) => {

  const { root: { $store } = {} } = context

  const isSaas = computed(() => $store.getters['system/isSaas'])

  const {
    k8s_services,
    services,
    system_services,
    systemd,
    value,
  } = toRefs(props)

  const k8sServicesSorted = computed(() => k8s_services.value.sort((a, b) => a.localeCompare(b)))
  const servicesSorted = computed(() => services.value.sort((a, b) => a.localeCompare(b)))
  const systemServicesSorted = computed(() => system_services.value.sort((a, b) => a.localeCompare(b)))

  const show = computed(() => !!value.value && !!(
    (!isSaas.value && (services.value.length || system_services.value.length || systemd.value)) ||
    (isSaas.value && k8s_services.value.length)
  ))

  return {
    show,
    k8sServicesSorted,
    servicesSorted,
    systemServicesSorted,
    isSaas
  }
}

// @vue/component
export default {
  name: 'base-services',
  components,
  props,
  setup
}
</script>
