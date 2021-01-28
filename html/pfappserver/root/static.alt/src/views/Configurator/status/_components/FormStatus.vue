<template>
  <b-card no-body>
    <b-card-header>
      <h4 class="d-inline mb-0" v-t="'Passwords'"></h4>
      <small class="text-muted ml-2" v-t="'Make sure to keep them in a secure place'"></small>
    </b-card-header>
    <div class="card-body">
      <b-card v-if="database.root_pass"
        no-body class="mb-3">
        <b-card-header>
          <h5 class="mb-0" v-t="'Database Root Account'"/>
        </b-card-header>
        <div class="card-body">
          <base-form-group :column-label="$i18n.t('Username')">root</base-form-group>
          <base-form-group :column-label="$i18n.t('Password')">
            <code>{{ database.root_pass }}</code>
            <b-button size="sm" variant="outline-primary" class="ml-2 text-nowrap" @click.stop.prevent="onClipboard(database.root_pass)">{{ $t('Copy to Clipboard') }}</b-button>
          </base-form-group>
        </div>
      </b-card>

      <b-card v-if="database.pass"
        no-body class="mb-3">
        <b-card-header>
          <h5 class="mb-0" v-t="'Database User Account'"/>
        </b-card-header>
        <div class="card-body">
          <base-form-group :column-label="$i18n.t('Username')">{{ database.user }}</base-form-group>
          <base-form-group :column-label="$i18n.t('Password')">
            <code>{{ database.pass }}</code>
            <b-button size="sm" variant="outline-primary" class="ml-2 text-nowrap" @click.stop.prevent="onClipboard(database.pass)">{{ $t('Copy to Clipboard') }}</b-button>
          </base-form-group>
        </div>
      </b-card>

      <b-card v-if="administrator.password"
        no-body>
        <b-card-header>
          <h5 class="mb-0" v-t="'Administrator Account'"/>
        </b-card-header>
        <div class="card-body">
          <base-form-group :column-label="$i18n.t('Username')">{{ administrator.pid }}</base-form-group>
          <base-form-group :column-label="$i18n.t('Password')">
            <code>{{ administrator.password }}</code>
            <b-button size="sm" variant="outline-primary" class="ml-2 text-nowrap" @click.stop.prevent="onClipboard(administrator.password)">{{ $t('Copy to Clipboard') }}</b-button>
          </base-form-group>
        </div>
      </b-card>
    </div>
  </b-card>
</template>
<script>
import {
  BaseFormGroup
} from '@/components/new/'

const components = {
  BaseFormGroup
}

import { computed, inject } from '@vue/composition-api'
import i18n from '@/utils/locale'

export const setup = (props, context) => {

  const { root: { $store } = {} } = context

  const state = inject('state') // Configurator
  const administrator = computed(() => state.value.administrator)
  const database = computed(() => state.value.database)

  const onClipboard = password => {
    try {
      navigator.clipboard.writeText(password).then(() => {
        $store.dispatch('notification/info', { message: i18n.t('Password copied to clipboard') })
      }).catch(() => {
        $store.dispatch('notification/danger', { message: i18n.t('Could not copy password to clipboard.') })
      })
    } catch (e) {
      $store.dispatch('notification/danger', { message: i18n.t('Clipboard not supported.') })
    }
  }

  return {
    administrator,
    database,
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
