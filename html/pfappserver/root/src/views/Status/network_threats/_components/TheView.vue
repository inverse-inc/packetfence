<template>
  <b-card no-body>
    <b-card-header>
      <h4 class="d-inline" v-t="'Network Threats'"></h4>
    </b-card-header>
    <div class="card-body">
      <b-row>
        <b-col cols="6">
          <b-tabs small class="fixed">
            <b-tab :title="$i18n.t('Categories')" class="border-1 border-right border-bottom border-left pb-1">
              <base-filter-categories />
            </b-tab>
          </b-tabs>
        </b-col>
        <b-col cols="6">
          <b-tabs small class="fixed">
            <b-tab :title="$i18n.t('Security Events')" class="border-1 border-right border-bottom border-left">
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

const setup = () => {

  return {}
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