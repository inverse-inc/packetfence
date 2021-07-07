<template>
  <b-form @submit.prevent ref="rootRef">
    <b-card no-body>
      <b-card-header>
        <b-button-close @click="goToCollection" v-b-tooltip.hover.left.d300 :title="$t('Close [ESC]')"><icon name="times"></icon></b-button-close>
        <h4 class="mb-0">{{ $t('Admin API Audit Log Entry')}} <strong v-text="id"></strong></h4>
      </b-card-header>
      <base-form-group :column-label="$t('Created At')">{{ item.created_at }}</base-form-group>
      <base-form-group :column-label="$t('User Name')">{{ item.user_name }}</base-form-group>
      <base-form-group :column-label="$t('Action')">{{ item.action }}</base-form-group>
      <base-form-group :column-label="$t('Object ID')">{{ item.object_id }}</base-form-group>
      <base-form-group :column-label="$t('URL')">{{ item.url }}</base-form-group>
      <base-form-group :column-label="$t('Method')">{{ item.method }}</base-form-group>
      <base-form-group :column-label="$t('Status Code')">{{ item.status }}</base-form-group>
      <base-form-group :column-label="$t('Request')"><div class="text-pre">{{ item.request }}</div></base-form-group>
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
  id: {
    type: String
  }
}

import { ref , toRefs, watch } from '@vue/composition-api'
import useEventEscapeKey from '@/composables/useEventEscapeKey'
import useEventJail from '@/composables/useEventJail'
import { useRouter } from '../_router'

const formatJSON = string => {
  if (string)
    return JSON.stringify(JSON.parse(string), undefined, 2)
}

const setup = (props, context) => {

  const {
    id
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
  $store.dispatch(`$_admin_api_audit_logs/getItem`, id.value).then(_item => {
    const { request = '', ...rest } = _item
    item.value = { request: formatJSON(request), ...rest }
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
