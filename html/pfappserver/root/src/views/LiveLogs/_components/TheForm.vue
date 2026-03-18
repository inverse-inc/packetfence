<template>
  <div class="live-logs-page">
    <div class="live-logs-header px-3 py-2 border-bottom">
      <h4 v-t="'Live Logs'" class="mb-0" />
    </div>
    <the-create-bar />
    <the-tabs />
    <b-card no-body class="live-logs-body border-top-0 rounded-0">
      <base-table-empty v-if="sessions.length === 0" icon="scroll" :text="$i18n.t('Start a session using the form above.')" class="flex-fill">{{ $i18n.t('No active sessions') }}</base-table-empty>
    </b-card>
  </div>
</template>

<script>
import { computed } from '@vue/composition-api'
import { BaseTableEmpty } from '@/components/new/'
import TheCreateBar from './TheCreateBar'
import TheTabs from './TheTabs'

const components = {
  BaseTableEmpty,
  TheCreateBar,
  TheTabs
}

const setup = (props, context) => {
  const { root: { $store } = {} } = context
  const sessions = computed(() => $store.getters['$_live_logs/sessions'])
  return { sessions }
}

// @vue/component
export default {
  name: 'the-form',
  inheritAttrs: false,
  components,
  setup
}
</script>

<style lang="scss">
.live-logs-page {
  margin-left: -15px;
  margin-right: -15px;
  display: flex;
  flex-direction: column;
  height: calc(100vh - 4rem);
  background: var(--white);
}
.live-logs-header {
  flex-shrink: 0;
}
.live-logs-body {
  display: flex !important;
  flex-direction: column;
  flex: 1 1 0;
  min-height: 0;
}
</style>
