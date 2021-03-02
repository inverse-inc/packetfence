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

import { provide, ref } from '@vue/composition-api'
import { pfActions } from '@/globals/pfActions'

const setup = (props, context) => {

  const { root: { $store } = {} } = context

  // provide actions to child components
  const actions = ref([])
  provide('actions', actions) // for FormGroupActions
  $store.dispatch('session/getAllowedUserActions').then(allowedActions => {
    actions.value = allowedActions.map(({action}) => {
      switch (action) {
        case 'set_access_duration':
        case 'set_access_level':
        case 'set_role':
        case 'set_unreg_date':
          return pfActions[`${action}_by_acl_user`] // remap action to user ACL
          // break
        default:
          return pfActions[action] // passthrough
      }
    })
  })
}

// @vue/component
export default {
  name: 'the-view-create',
  inheritAttrs: false,
  components,
  setup
}
</script>
