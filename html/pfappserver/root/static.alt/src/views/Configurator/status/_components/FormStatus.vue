<template>
  <b-card no-body>
    <b-card-header>
      <h4 class="d-inline mb-0" v-html="$t('Administrator')"/>
    </b-card-header>

<pre>{{ {state} }}</pre>

  </b-card>
</template>
<script>
import {
  BaseFormGroup
} from '@/components/new/'

const components = {
  BaseFormGroup
}

import { computed, inject, ref } from '@vue/composition-api'
import i18n from '@/utils/locale'

export const setup = (props, context) => {

  const { root: { $store } = {} } = context

  const state = inject('state') // Configurator

  const onClipboard = () => {
    try {
      navigator.clipboard.writeText(form.value.password).then(() => {
        $store.dispatch('notification/info', { message: i18n.t('Password copied to clipboard') })
      }).catch(() => {
        $store.dispatch('notification/danger', { message: i18n.t('Could not copy password to clipboard.') })
      })
    } catch (e) {
      $store.dispatch('notification/danger', { message: i18n.t('Clipboard not supported.') })
    }
  }


  return {
    state,
    onClipboard
  }
}

// @vue/component
export default {
  name: 'form-status',
  inheritAttrs: false,
  components,
  setup
}
</script>
