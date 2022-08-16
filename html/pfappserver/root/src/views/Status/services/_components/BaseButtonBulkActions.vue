<template>
  <b-dropdown ref="buttonRef"
    variant="outline-primary" toggle-class="text-decoration-none" no-flip>
    <template #button-content>
      <slot name="default">{{ $i18n.t('{num} selected', { num: selectedItems.length }) }}</slot>
    </template>
    <b-dropdown-group v-if="isCluster"
      :header="$i18n.t('CLUSTER')">
      <b-dropdown-item @click="doEnableCluster" @click.stop="onClick" :disabled="isLoading"><icon name="toggle-on" class="mr-1" /> {{ $i18n.t('Enable All') }}</b-dropdown-item>
      <b-dropdown-item @click="doDisableCluster" @click.stop="onClick" :disabled="isLoading"><icon name="toggle-off" class="mr-1" /> {{ $i18n.t('Disable All') }}</b-dropdown-item>
      <b-dropdown-item @click="doRestartCluster" @click.stop="onClick" :disabled="isLoading"><icon name="redo" class="mr-1" /> {{ $i18n.t('Restart All') }}</b-dropdown-item>
      <b-dropdown-item @click="doStartCluster" @click.stop="onClick" :disabled="isLoading"><icon name="play" class="mr-1" /> {{ $i18n.t('Start All') }}</b-dropdown-item>
      <b-dropdown-item @click="doStopCluster" @click.stop="onClick" :disabled="isLoading"><icon name="stop" class="mr-1" /> {{ $i18n.t('Stop All') }}</b-dropdown-item>
    </b-dropdown-group>
    <template v-for="(_, server) in servers">
      <b-dropdown-divider v-if="isCluster" :key="`divider-${server}`" />
      <b-dropdown-group :key="`group-${server}`"
        :header="server">
        <b-dropdown-item @click="doEnableServer(server)" @click.stop="onClick" :disabled="isLoading"><icon name="toggle-on" class="mr-1" /> {{ $i18n.t('Enable') }}</b-dropdown-item>
        <b-dropdown-item @click="doDisableServer(server)" @click.stop="onClick" :disabled="isLoading"><icon name="toggle-off" class="mr-1" /> {{ $i18n.t('Disable') }}</b-dropdown-item>
        <b-dropdown-item @click="doRestartServer(server)" @click.stop="onClick" :disabled="isLoading"><icon name="redo" class="mr-1" /> {{ $i18n.t('Restart') }}</b-dropdown-item>
        <b-dropdown-item @click="doStartServer(server)" @click.stop="onClick" :disabled="isLoading"><icon name="play" class="mr-1" /> {{ $i18n.t('Start') }}</b-dropdown-item>
        <b-dropdown-item @click="doStopServer(server)" @click.stop="onClick" :disabled="isLoading"><icon name="stop" class="mr-1" /> {{ $i18n.t('Stop') }}</b-dropdown-item>
      </b-dropdown-group>
    </template>
  </b-dropdown>
</template>
<script>

const props = {
  selectedItems: {
    type: Array
  },
  visibleColumns: {
    type: Array
  }
}

import { computed, nextTick, ref, toRefs } from '@vue/composition-api'
import i18n from '@/utils/locale'
import { localeStrings } from '../config'

const setup = (props, context) => {

  const buttonRef = ref(null)

  const onClick = () => {
    nextTick(() => {
      buttonRef.value.show() // keep open on click
    })
  }

  const {
    selectedItems
  } = toRefs(props)
  const selectedItemsCsv = computed(() => selectedItems.value.map(({ service }) => `<code>${service}</code>`).join(', '))

  const { root: { $store } = {} } = context

  const isCluster = computed(() => true /*$store.getters['cluster/isCluster']*/)
  const isLoading = computed(() => $store.getters['cluster/isLoading'])
  const servers = computed(() => $store.state.cluster.servers)

  const doDisableCluster = () => {
    Promise.all(
      selectedItems.value.map(({ service }) => $store.dispatch('cluster/disableServiceCluster', service).catch(e => e))
    ).then(() => {
      $store.dispatch('notification/info', { url: 'CLUSTER', message: i18n.t(localeStrings.SERVICES_DISABLED_SUCCESS, { services: selectedItemsCsv.value }) })
    }).catch(() => {
      $store.dispatch('notification/info', { url: 'CLUSTER', message: i18n.t(localeStrings.SERVICES_DISABLED_ERROR, { services: selectedItemsCsv.value }) })
    })
  }

  const doEnableCluster = () => {
    Promise.all(
      selectedItems.value.map(({ service }) => $store.dispatch('cluster/enableServiceCluster', service).catch(e => e))
    ).then(() => {
      $store.dispatch('notification/info', { url: 'CLUSTER', message: i18n.t(localeStrings.SERVICES_ENABLED_SUCCESS, { services: selectedItemsCsv.value }) })
    }).catch(() => {
      $store.dispatch('notification/info', { url: 'CLUSTER', message: i18n.t(localeStrings.SERVICES_ENABLED_ERROR, { services: selectedItemsCsv.value }) })
    })
  }

  const doRestartCluster = () => {
    Promise.all(
      selectedItems.value.map(({ service }) => $store.dispatch('cluster/restartServiceCluster', service).catch(e => e))
    ).then(() => {
      $store.dispatch('notification/info', { url: 'CLUSTER', message: i18n.t(localeStrings.SERVICES_RESTARTED_SUCCESS, { services: selectedItemsCsv.value }) })
    }).catch(() => {
      $store.dispatch('notification/info', { url: 'CLUSTER', message: i18n.t(localeStrings.SERVICES_RESTARTED_ERROR, { services: selectedItemsCsv.value }) })
    })
  }

  const doStartCluster = () => {
    Promise.all(
      selectedItems.value.map(({ service }) => $store.dispatch('cluster/startServiceCluster', service).catch(e => e))
    ).then(() => {
      $store.dispatch('notification/info', { url: 'CLUSTER', message: i18n.t(localeStrings.SERVICES_STARTED_SUCCESS, { services: selectedItemsCsv.value }) })
    }).catch(() => {
      $store.dispatch('notification/info', { url: 'CLUSTER', message: i18n.t(localeStrings.SERVICES_STARTED_ERROR, { services: selectedItemsCsv.value }) })
    })
  }

  const doStopCluster = () => {
    Promise.all(
      selectedItems.value.map(({ service }) => $store.dispatch('cluster/stopServiceCluster', service).catch(e => e))
    ).then(() => {
      $store.dispatch('notification/info', { url: 'CLUSTER', message: i18n.t(localeStrings.SERVICES_STOPPED_SUCCESS, { services: selectedItemsCsv.value }) })
    }).catch(() => {
      $store.dispatch('notification/info', { url: 'CLUSTER', message: i18n.t(localeStrings.SERVICES_STOPPED_ERROR, { services: selectedItemsCsv.value }) })
    })
  }

  const doDisableServer = server => {
    Promise.all(
      selectedItems.value.map(({ service }) => $store.dispatch('cluster/disableService', { server, id: service }).catch(e => e))
    ).then(() => {
      $store.dispatch('notification/info', { url: server, message: i18n.t(localeStrings.SERVICES_DISABLED_SUCCESS, { services: selectedItemsCsv.value }) })
    }).catch(() => {
      $store.dispatch('notification/info', { url: 'CLUSTER', message: i18n.t(localeStrings.SERVICES_DISABLED_ERROR, { services: selectedItemsCsv.value }) })
    })
  }

  const doEnableServer = server => {
    Promise.all(
      selectedItems.value.map(({ service }) => $store.dispatch('cluster/enableService', { server, id: service }).catch(e => e))
    ).then(() => {
      $store.dispatch('notification/info', { url: server, message: i18n.t(localeStrings.SERVICES_ENABLED_SUCCESS, { services: selectedItemsCsv.value }) })
    }).catch(() => {
      $store.dispatch('notification/info', { url: 'CLUSTER', message: i18n.t(localeStrings.SERVICES_ENABLED_ERROR, { services: selectedItemsCsv.value }) })
    })
  }

  const doRestartServer = server => {
    Promise.all(
      selectedItems.value.map(({ service }) => $store.dispatch('cluster/restartService', { server, id: service }).catch(e => e))
    ).then(() => {
      $store.dispatch('notification/info', { url: server, message: i18n.t(localeStrings.SERVICES_RESTARTED_SUCCESS, { services: selectedItemsCsv.value }) })
    }).catch(() => {
      $store.dispatch('notification/info', { url: 'CLUSTER', message: i18n.t(localeStrings.SERVICES_RESTARTED_ERROR, { services: selectedItemsCsv.value }) })
    })
  }

  const doStartServer = server => {
    Promise.all(
      selectedItems.value.map(({ service }) => $store.dispatch('cluster/startService', { server, id: service }).catch(e => e))
    ).then(() => {
      $store.dispatch('notification/info', { url: server, message: i18n.t(localeStrings.SERVICES_STARTED_SUCCESS, { services: selectedItemsCsv.value }) })
    }).catch(() => {
      $store.dispatch('notification/info', { url: 'CLUSTER', message: i18n.t(localeStrings.SERVICES_STARTED_ERROR, { services: selectedItemsCsv.value }) })
    })
  }

  const doStopServer = server => {
    Promise.all(
      selectedItems.value.map(({ service }) => $store.dispatch('cluster/stopService', { server, id: service }).catch(e => e))
    ).then(() => {
      $store.dispatch('notification/info', { url: server, message: i18n.t(localeStrings.SERVICES_STOPPED_SUCCESS, { services: selectedItemsCsv.value }) })
    }).catch(() => {
      $store.dispatch('notification/info', { url: 'CLUSTER', message: i18n.t(localeStrings.SERVICES_STOPPED_ERROR, { services: selectedItemsCsv.value }) })
    })
  }

  return {
    buttonRef,
    onClick,
    isCluster,
    isLoading,
    servers,

    doDisableCluster,
    doEnableCluster,
    doRestartCluster,
    doStartCluster,
    doStopCluster,

    doDisableServer,
    doEnableServer,
    doRestartServer,
    doStartServer,
    doStopServer
  }
}

// @vue/component
export default {
  name: 'base-button-bulk-actions',
  inheritAttrs: false,
  props,
  setup
}
</script>

<style lang="scss">
  // remove bootstrap background color
  .b-table-top-row {
    background: none !important;
  }
</style>