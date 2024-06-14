<template>
  <b-card no-body>
    <b-card-header>
      <b-button-close @click="onClose" v-b-tooltip.hover.left.d300 :title="$t('Close [ESC]')"><icon name="times"/></b-button-close>
      <h4 class="d-inline mb-0">
        MAC <strong v-text="id" />
      </h4>
      <b-container fluid class="px-0 mt-3">
        <span v-if="node.status === 'reg'" class="mr-1">
          <icon name="check-circle" /> {{ $t('registered') }}
        </span>
        <span v-else-if="node.status === 'unreg'" class="mr-1">
          <icon name="regular/times-circle" /> {{ $t('unregistered') }}
        </span>
        <span v-else class="ml-1">
          <icon name="regular/dot-circle" /> {{ $t('pending') }}
        </span>

        <span v-if="node.online === 'on'" class="ml-1">
          <icon name="circle" class="text-success" /> {{ $t('on') }}
        </span>
        <span v-else-if="node.online === 'off'" class="ml-1">
          <icon name="circle" class="text-danger" /> {{ $t('off') }}
        </span>
        <span v-else
          v-b-tooltip.right.d300 class="ml-1">
          <icon name="question-circle" class="text-warning" /> {{ $t('unknown') }}
        </span>
      </b-container>
    </b-card-header>
    <b-tabs ref="tabsRef" v-model="tabIndex" card>
      <base-form-tab :title="$i18n.t('Edit')" active>
        <the-form-update :id="id" />
      </base-form-tab>
      <tab-info :id="id" />
      <tab-fingerbank :id="id" />
      <tab-timeline :id="id" />
      <tab-ip4-logs :id="id" />
      <tab-ip6-logs :id="id" />
      <tab-location-logs :id="id" />
      <tab-security-events :id="id" />
      <tab-dhcp-option82-logs :id="id" />
    </b-tabs>
  </b-card>
</template>

<script>
import { BaseFormTab } from '@/components/new/'
import TheFormUpdate from './TheFormUpdate'
import TabDhcpOption82Logs from './TabDhcpOption82Logs'
import TabFingerbank from './TabFingerbank'
import TabInfo from './TabInfo'
import TabIp4Logs from './TabIp4Logs'
import TabIp6Logs from './TabIp6Logs'
import TabSecurityEvents from './TabSecurityEvents'
import TabLocationLogs from './TabLocationLogs'
import TabTimeline from './TabTimeline'

const components = {
  BaseFormTab,
  TheFormUpdate,
  TabDhcpOption82Logs,
  TabFingerbank,
  TabInfo,
  TabIp4Logs,
  TabIp6Logs,
  TabSecurityEvents,
  TabLocationLogs,
  TabTimeline
}

const props = {
  id: { // from router
    type: String
  }
}

import { computed, ref, toRefs, watch } from '@vue/composition-api'
import useEventEscapeKey from '@/composables/useEventEscapeKey'
import { usePropsWrapper } from '@/composables/useProps'
import { useStore } from '../_composables/useCollection'

const setup = (props, context) => {

  const {
    id
  } = toRefs(props)

  const { root: { $router, $store } = {} } = context

  const tabsRef = ref(null)
  const tabIndex = ref(0)

  // merge props w/ params in useStore methods
  const _useStore = $store => usePropsWrapper(useStore($store), props)
  const {
    isLoading,
    reloadItem
  } = _useStore($store)

  const onClose = () => $router.back()

  const onRefresh = () => reloadItem()

  const escapeKey = useEventEscapeKey()
  watch(escapeKey, () => onClose())

  const node = computed(() => $store.state.$_nodes.nodes[id.value] || {})

  return {
    tabsRef,
    tabIndex,
    isLoading,
    onClose,
    onRefresh,
    node
  }
}

// @vue/component
export default {
  name: 'the-view-update',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
