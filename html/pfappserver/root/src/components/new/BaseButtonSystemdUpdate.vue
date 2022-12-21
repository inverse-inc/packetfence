<template>
  <b-dropdown ref="buttonRef"
    :disabled="isDisabled"
    :size="size"
    :text="service"
    no-flip
    variant="outline-primary"
    v-b-tooltip.hover.top.d300 :title="tooltip"
    v-bind="$attrs"
  >
    <template v-slot:button-content>
      <div class="d-inline px-1">
        <icon v-if="!servers.length"
          name="circle-notch" spin class="fa-overlap mr-1" />
        <icon v-else-if="!Object.entries(cluster).length"
          v-for="server of servers" :key="`icon-${server}`"
          name="circle" class="text-secondary fa-overlap mr-1" />
        <template v-else
          v-for="(service, server) in cluster">
          <icon v-if="service.status === 'loading'" :key="`icon-${server}`"
            name="circle-notch" spin class="text-primary fa-overlap mr-1" />
          <icon v-else-if="service.status === 'error'" :key="`icon-${server}`"
            name="exclamation-triangle" class="text-danger fa-overlap mr-1" />
          <icon v-else-if="service.status === 'updating'" :key="`icon-${server}`"
            class="fa-overlap mr-1">
            <icon name="circle" class="text-white" />
            <icon v-if="service.status === 'updating'"
              name="sync" class="text-primary" scale="0.5" />
          </icon>
          <icon v-else :key="`icon-${server}`"
            name="circle" class="text-success fa-overlap mr-1" />
        </template>
        systemd
      </div>
    </template>

    <b-dropdown-group v-if="isAllowed && isCluster"
      :header="$i18n.t('CLUSTER')">
      <b-dropdown-item @click="doUpdateAll" @click.stop="onClick" :disabled="isLoading"><icon name="sync" class="mr-1" /> {{ $t('Update All Sequentially') }}</b-dropdown-item>
    </b-dropdown-group>

    <template v-for="server of servers">
      <b-dropdown-divider v-if="isCluster" :key="`divider-${server}`" />
      <b-dropdown-group :key="`group-${server}`">
       <template v-slot:header>
         {{ server }}
        </template>
        <b-dropdown-form style="width: 400px;">
          <base-systemd-update :id="service" :server="server" v-bind="{ acl }" />
        </b-dropdown-form>
      </b-dropdown-group>
    </template>
  </b-dropdown>
</template>
<script>
import BaseSystemdUpdate from './BaseSystemdUpdate'

const components = {
  BaseSystemdUpdate
}

import { computed, nextTick, ref, toRefs } from '@vue/composition-api'
import acl from '@/utils/acl'
import i18n from '@/utils/locale'
import { localeStrings } from '@/globals/pfLocales'

const props = {
  service: {
    type: String,
    default: 'pf'
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
    default: 'SERVICES_UPDATE'
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

  const cluster = computed(() => {
    const { [service.value]: { servers = {} } = {}  } = $store.getters['cluster/systemdByServer']
    return servers
  })
  const servers = computed(() => $store.getters['cluster/servers'])
  const isCluster = computed(() => $store.getters['cluster/isCluster'])
  const isLoading = computed(() => $store.getters['cluster/isLoading'])
  const isDisabled = computed(() => disabled.value || !isAllowed.value || !servers.value.length)

  const tooltip = computed(() => {
    switch (true) {
      case !isAllowed.value:
        return i18n.t('No permission, admin role {acl} required.', { acl: _acl.value })
        //break

      default:
        return undefined
    }
  })

  const doUpdate = server => $store.dispatch('cluster/updateSystemd', { server, id: service.value }).then(() => {
    $store.dispatch('notification/info', { url: server, message: i18n.t(localeStrings.SYSTEMD_UPDATED_SUCCESS, { service: `<code>${service.value}</code>` }) })
    emit('update', { server, id: service.value })
  }).catch(() => {
    $store.dispatch('notification/danger', { url: server, message: i18n.t(localeStrings.SYSTEMD_UPDATED_ERROR, { service: `<code>${service.value}</code>` }) })
  })

  const doUpdateAll = () => $store.dispatch('cluster/updateSystemdCluster', service.value).then(() => {
    $store.dispatch('notification/info', { url: 'CLUSTER', message: i18n.t(localeStrings.SYSTEMD_UPDATED_SUCCESS, { service: `<code>${service.value}</code>` }) })
    emit('update', { id: service.value })
  }).catch(() => {
    $store.dispatch('notification/danger', { url: 'CLUSTER', message: i18n.t(localeStrings.SYSTEMD_UPDATED_ERROR, { service: `<code>${service.value}</code>` }) })
  })

   return {
    buttonRef,
    onClick,

    isAllowed,
    isCluster,
    isDisabled,
    isLoading,
    cluster,
    servers,
    tooltip,

    doUpdate,
    doUpdateAll,
  }
}

// @vue/component
export default {
  name: 'base-button-systemd-update',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
