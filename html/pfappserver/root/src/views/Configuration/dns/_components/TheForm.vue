<template>
  <base-form
    :form="form"
    :meta="meta"
    :schema="schema"
    :isLoading="isLoading"
  >
    <v-model-switch v-model="uiForm['record_dns_in_sql']"
                    :column-label="$i18n.t('Record DNS')"
                    :text="$i18n.t('Record DNS requests and replies in the SQL tables.')"
    />
  </base-form>
</template>
<script>
import {computed, ref, toRefs, watch} from '@vue/composition-api'
import {BaseForm} from '@/components/new/'
import vModelSwitch from './vModelSwitch.vue'
import schemaFn from '../schema'
import {FormGroupRecordDnsInSql} from './'
import _ from 'lodash'
import {
  useParseBoolean
} from '@/views/Configuration/dns/_composables/_api_parsing_layer/parseBoolean';

const components = {
  BaseForm,
  vModelSwitch,
  FormGroupRecordDnsInSql
}

export const props = {
  form: {
    type: Object
  },
  meta: {
    type: Object
  },
  isLoading: {
    type: Boolean,
    default: false
  }
}

export const setup = (props) => {

  const schema = computed(() => schemaFn(props))

  // props.form come in undefined.
  // Adding a watcher to trigger when it gets a value fail.
  // I don't know how to work around it, so this form doesn't work

  // The idea is to clone the form and link it to the UI form.
  // UI form would use whatever UI components need and backend form would get computed.
  const uiForm = _.cloneDeep(props.form)
  uiForm.value['record_dns_in_sql'] = (props.form['record_dns_in_sql'] === "enabled")
  props.form['record_dns_in_sql'] = computed(() => {
    return uiForm['record_dns_in_sql'] ? "enabled" : "disabled"
  })

  return {
    schema,
    uiForm,
  }
}

// @vue/component
export default {
  name: 'the-form',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>

