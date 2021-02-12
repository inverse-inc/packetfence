<template>
  <b-card no-body>
    <b-card-header>
      <h4 class="mb-0" v-t="'Create Users'"></h4>
    </b-card-header>
    <b-tabs card>
      <!--
        SINGLE
        -->
      <b-tab :title="$t('Single')">
          <the-form-create-single />
      </b-tab>
      <!--
        MULTIPLE
        -->
      <template v-can:create-multiple="'users'">
        <b-tab :title="$t('Multiple')">
          <the-form-create-multiple />
        </b-tab>
      </template>
    </b-tabs>
  </b-card>
</template>
<script>

import TheFormCreateSingle from './TheFormCreateSingle'
import TheFormCreateMultiple from './TheFormCreateMultiple'

const components = {
  TheFormCreateSingle,
  TheFormCreateMultiple
}

// @vue/component
export default {
  name: 'the-view-create',
  inheritAttrs: false,
  components
}
</script>
