<template>
  <b-card no-body>
    <b-card-header>
      <h4 class="d-inline" v-t="'Network Threats'"></h4>
    </b-card-header>
    <div class="card-body">
      <b-row>
        <b-col cols="6">
          <b-tabs small class="fixed">
            <b-tab class="border-1 border-right border-bottom border-left pb-1">
              <template #title>
                {{ $i18n.t('Categories') }} <b-badge v-if="selectedCategories.length" pill variant="primary" class="ml-1">{{ selectedCategories.length }}</b-badge>
              </template>
              <base-filter-categories />
            </b-tab>
          </b-tabs>
        </b-col>
        <b-col cols="6">
          <b-tabs small class="fixed">
            <b-tab class="border-1 border-right border-bottom border-left">
              <template #title>
                {{ $i18n.t('Security Events') }} <b-badge v-if="selectedSecurityEvents.length" pill variant="primary" class="ml-1">{{ selectedSecurityEvents.length }}</b-badge>
              </template>
              <base-filter-security-events />
            </b-tab>
          </b-tabs>
        </b-col>
      </b-row>

      The Data

    </div>
  </b-card>
</template>

<script>
import BaseFilterCategories from './BaseFilterCategories'
import BaseFilterSecurityEvents from './BaseFilterSecurityEvents'
const components = {
  BaseFilterCategories,
  BaseFilterSecurityEvents
}

import { computed } from '@vue/composition-api'
const setup = (props, context) => {

    const { root: { $store } = {} } = context

    const selectedCategories = computed(() => $store.state.$_network_threats.selectedCategories)
    const selectedSecurityEvents = computed(() => $store.state.$_network_threats.selectedSecurityEvents)

  return {
    selectedCategories,
    selectedSecurityEvents,
  }
}

// @vue/component
export default {
  name: 'the-view',
  inheritAttrs: false,
  components,
  setup
}
</script>

<style lang="scss">
.tabs.fixed {
  div[role="tabpanel"] {
    height: 50vh;
    overflow-y: auto;
    overflow-x: hidden;
    .card {
      border: 0px !important;
      box-shadow: 0px 0px 0px 0px !important;
    }
  }
}
</style>