<template>
  <b-card no-body>
    <b-card-header>
      <b-button-close @click="onClose" v-b-tooltip.hover.left.d300 :title="$t('Close [ESC]')"><icon name="times"></icon></b-button-close>
      <h4 class="mb-0" v-html="$t('User {pid}', { pid: $strong(pid) })"></h4>
    </b-card-header>
    <the-form-update :pid="pid" />
  </b-card>
</template>
<script>
import TheFormUpdate from './TheFormUpdate'

const components = {
  TheFormUpdate
}

const props = {
  pid: {
    type: String
  }
}

import { provide, ref } from '@vue/composition-api'
import { pfActions } from '@/globals/pfActions'

const setup = (props, context) => {

  const { root: { $router, $store } = {} } = context

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
  
  const onClose = () => $router.back()
    
  return {
    onClose
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
