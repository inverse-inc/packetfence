<template>
  <b-card no-body>
    <b-card-header>
      <h4 class="d-inline mb-0" v-html="$t('Fingerbank')"/>
    </b-card-header>
    <b-form>
      <div v-if="!fingerbankAccountName"
        class="alert alert-info m-3">
        <h4 class="alert-heading">{{ $i18n.t('This step is optional') }}</h4>
        <p class="mb-0" v-html="fingerbankAccountSignup" />
      </div>

      <base-form
        :form="form"
        :schema="schema"
        :isLoading="isLoading"
      >


<span>e33c03a18a3af6610ad9324837a9903c9e22abe9</span>
<pre>{{ {form} }}</pre>

        <base-form-group-input namespace="api_key"
          :column-label="$i18n.t('API Key')"
          :text="$i18n.t('API key to interact with upstream Fingerbank project. Changing this value requires to restart the Fingerbank collector.')"
          :valid-feedback="(fingerbankAccountName) ? $i18n.t('API key is valid.') : null"
        />

        <template v-if="!fingerbankAccountName">
          <base-form-group v-if="isPassword"
            class="mb-3">
            <b-button class="col-sm-7 col-lg-5 col-xl-4" variant="outline-primary"
              @click="onVerify">{{ $t('Verify') }}</b-button>
          </base-form-group>
        </template>
      </base-form>
    </b-form>
  </b-card>
</template>
<script>
import {
  BaseForm,
  BaseFormGroup,
  BaseFormGroupInput
} from '@/components/new/'

const components = {
  BaseForm,
  BaseFormGroup,
  BaseFormGroupInput
}

import { computed, ref } from '@vue/composition-api'
import i18n from '@/utils/locale'
import yup from '@/utils/yup'

const schemaFn = () => yup.object({
  pid: yup.string().nullable().required(i18n.t('Administrator username required.')),
  password: yup.string().nullable().required(i18n.t('Administrator password required.'))
})

export const setup = (props, context) => {

  const { root: { $store } = {} } = context

  const form = ref({})
  const meta = ref({})
  const schema = computed(() => schemaFn(props))
  const fingerbankAccountName = ref(null)

  const fingerbankAccountSignup = i18n.t(
    'You can visit the official <a href="{link}" target="_new">registration page</a> to create an account and get an API key.',
    { link: 'https://api.fingerbank.org/users/register' }
  )

  $store.dispatch('$_fingerbank/optionsGeneralSettings').then(({ meta: _meta }) => {
    meta.value = _meta
  })

  $store.dispatch('$_fingerbank/getGeneralSettings').then(_form => {
    const { upstream, upstream: { api_key = null } = {} } = _form
    form.value = upstream
    if (api_key) {
      $store.dispatch('$_fingerbank/getAccountInfo').then(({ name }) => {
        fingerbankAccountName.value = name
      })
    }
  })

  const isLoading = computed(() => $store.getters['$_fingerbank/isGeneralSettingsLoading'])

  const onVerify = () => {
    $store.dispatch('$_fingerbank/setGeneralSettings', { upstream: { ...form.value, quiet: true } }).then(() => {
      $store.dispatch('$_fingerbank/getAccountInfo').then(({ name }) => {
        fingerbankAccountName.value = name
      })
    }).catch(() => {
      fingerbankAccountName.value = null
    })
  }

  const onSave = () => {

  }

  return {
    form,
    meta,
    schema,
    fingerbankAccountName,
    fingerbankAccountSignup,
    isLoading,
    onSave,
    onVerify
  }
}

// @vue/component
export default {
  name: 'form-fingerbank',
  inheritAttrs: false,
  components,
  setup
}
</script>
