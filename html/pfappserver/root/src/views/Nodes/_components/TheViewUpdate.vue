<template>
  <b-card no-body>
    <b-card-header>
      <b-button-close @click="onClose" v-b-tooltip.hover.left.d300 :title="$t('Close [ESC]')"><icon name="times"/></b-button-close>
      <h4 class="d-inline mb-0">MAC <strong v-text="id"></strong></h4>
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
      <!-- TODO
      <b-tab title="WMI Rules">
        <template v-slot:title>
          {{ $t('WMI Rules') }}
        </template>
      </b-tab>
      -->
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

import { ref, watch } from '@vue/composition-api'
import useEventEscapeKey from '@/composables/useEventEscapeKey'
import { useStore } from '../_composables/useCollection'

const setup = (props, context) => {

  const { root: { $router } = {} } = context

  const tabsRef = ref(null)
  const tabIndex = ref(0)

  const {
    isLoading,
    reloadItem
  } = useStore(props, context)

  const onClose = () => $router.back()

  const onRefresh = () => reloadItem()

  const escapeKey = useEventEscapeKey()
  watch(escapeKey, () => onClose())

  return {
    tabsRef,
    tabIndex,
    isLoading,
    onClose,
    onRefresh
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
