<template>
  <b-form @submit.prevent ref="rootRef">
    <b-card no-body>
      <b-card-header>
        <b-button-close @click="close" v-b-tooltip.hover.left.d300 :title="$t('Close [ESC]')"><icon name="times"></icon></b-button-close>
        <h4 class="mb-0">{{ $t('DNS Log Entry')}} <strong v-text="id"></strong></h4>
      </b-card-header>
      <base-form-group :column-label="$t('Created At')">{{ item.created_at }}</base-form-group>
      <base-form-group :column-label="$t('IP Address')">{{ item.ip }}</base-form-group>
      <base-form-group :column-label="$t('MAC Address')">{{ item.mac }}</base-form-group>
      <base-form-group :column-label="$t('Qname')">{{ item.qname }}</base-form-group>
      <base-form-group :column-label="$t('Qtype')">{{ item.qtype }}</base-form-group>
      <base-form-group :column-label="$t('Answer')">{{ item.answer }}</base-form-group>
      <base-form-group :column-label="$t('Scope')">{{ item.scope }}</base-form-group>
    </b-card>
  </b-form>
</template>

<script>
import {
  BaseFormGroup
} from '@/components/new/'

const components = {
  BaseFormGroup
}

const props = {
  mac: {
    type: String
  }
}

import { ref , toRefs, watch } from '@vue/composition-api'
import useEventEscapeKey from '@/composables/useEventEscapeKey'
import useEventJail from '@/composables/useEventJail'
import { useRouter } from '../_router'

const setup = (props, context) => {

  const {
    mac
  } = toRefs(props)

  const { root: { $router, $store } = {} } = context

  const {
    goToCollection
  } = useRouter($router)

  // template refs
  const rootRef = ref(null)
  useEventJail(rootRef)
  const escapeKey = useEventEscapeKey(rootRef)
  watch(escapeKey, () => goToCollection())

  const item = ref({})
  $store.dispatch(`$_dns_logs/getItem`, mac.value).then(_item => {
    item.value = _item
  })

  return {
    rootRef,
    item,
    goToCollection
  }
}

export default {
  name: 'the-view',
  components,
  props,
  setup
}
</script>
