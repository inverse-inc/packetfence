<template>
  <b-card no-body>
    <b-card-header>
      <h4 class="d-inline mb-0" v-t="'Fingerbank'"/>
    </b-card-header>
    <b-form>
      <div v-if="!fingerbankAccountName && !isLoading"
        class="alert alert-info m-3">
        <h4 class="alert-heading">{{ $i18n.t('This step is optional') }}</h4>
        <p class="mb-0" v-html="fingerbankAccountSignup" />
      </div>
      <base-form
        :form="form"
        :schema="schema"
        :isLoading="isLoading"
      >
        <base-form-group-input namespace="api_key"
          :column-label="$i18n.t('API Key')"
          :text="$i18n.t('API key to interact with upstream Fingerbank project. Changing this value requires to restart the Fingerbank collector.')"
          :valid-feedback="(fingerbankAccountName) ? $i18n.t('API key is valid.') : undefined"
        />

        <template v-if="!fingerbankAccountName && form.api_key && form.api_key.length > 0">
          <base-form-group class="mb-3"
            :class="{
              'is-invalid': !fingerbankAccountIsValid
            }">
            <b-button class="col-sm-7 col-lg-5 col-xl-4"
              :variant="(!fingerbankAccountIsValid) ? 'outline-danger' : 'outline-primary'"
              :disabled="isLoading"
              @click="onVerify">{{ $t('Verify') }}</b-button>

            <div v-if="!fingerbankAccountIsValid"
              class="d-block invalid-feedback p-2">{{ $i18n.t('Invalid API key.') }}</div>
          </base-form-group>
        </template>

        <template v-if="fingerbankAccountName">
          <base-form-group class="mb-3">
            <div class="alert alert-info w-100">
              <p class="mb-0" v-html="$i18n.t('The API key is associated to Fingerbank account <b>{name}</b>', { name: fingerbankAccountName })" />
            </div>
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

import { computed, inject, ref, watch } from '@vue/composition-api'
import i18n from '@/utils/locale'
import yup from '@/utils/yup'

const schemaFn = () => yup.object({
  api_key: yup.string().nullable()
})

export const setup = (props, context) => {

  const { root: { $store } = {} } = context

  const state = inject('state') // Configurator
  const form = ref({})
  const meta = ref({})
  const schema = computed(() => schemaFn(props))
  const fingerbankAccountName = ref(null)
  const fingerbankAccountIsValid = ref(true)

  // double-quote workaround, embedding this in the template markup yields a parsing error
  const fingerbankAccountSignup = i18n.t(
    'You can visit the official <a href="{link}" target="_new">registration page</a> to create an account and get an API key.',
    { link: 'https://api.fingerbank.org/users/register' }
  )

  $store.dispatch('$_fingerbank/optionsGeneralSettings').then(({ meta: _meta }) => {
    meta.value = _meta
  })

  const _isLoadingSettings = ref(false)
  const isLoading = computed(() => _isLoadingSettings.value || $store.getters['$_fingerbank/isGeneralSettingsLoading'])

  const _getAccountInfo = () => {
    _isLoadingSettings.value = true
    return $store.dispatch('$_fingerbank/getGeneralSettings')
      .then(_form => {
        state.value.fingerbank = _form
        const { upstream, upstream: { api_key = null } = {} } = _form
        form.value = upstream
        if (api_key) {
          $store.dispatch('$_fingerbank/getAccountInfo').then(({ name }) => {
            fingerbankAccountName.value = name
          })
        }
      })
      .finally(() => {
        _isLoadingSettings.value = false
      })
  }
  _getAccountInfo() // init

  const onVerify = () => {
    _isLoadingSettings.value = true
    $store.dispatch('$_fingerbank/setGeneralSettings', { upstream: { ...form.value, quiet: true } })
      .then(() => {
        fingerbankAccountIsValid.value = true
        _getAccountInfo()
      })
      .catch(() => {
        fingerbankAccountName.value = null
        fingerbankAccountIsValid.value = false
      })
      .finally(() => {
        _isLoadingSettings.value = false
      })
  }

  // when api_key is mutated disassociate account
  watch(() => form.value.api_key, () => {
    fingerbankAccountName.value = null
  })

  return {
    form,
    meta,
    schema,
    fingerbankAccountName,
    fingerbankAccountIsValid,
    fingerbankAccountSignup,
    isLoading,
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
