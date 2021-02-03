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
        <form-group-proxy-use-proxy namespace="proxy.use_proxy"
          :column-label="$i18n.t('Use proxy')"
          :text="$i18n.t('Should Fingerbank interact with WWW using a proxy?')"
        />

        <template v-if="isProxy">
          <form-group-proxy-host namespace="proxy.host"
            :column-label="$i18n.t('Proxy Host')"
            :text="$i18n.t('Host the proxy is listening on. Only the host must be specified here without any port or protocol.')"
          />

          <form-group-proxy-port namespace="proxy.port"
            :column-label="$i18n.t('Proxy Port')"
            :text="$i18n.t('Port the proxy is listening on.')"
          />

          <form-group-proxy-verify-ssl namespace="proxy.verify_ssl"
            :column-label="$i18n.t('Verify SSL')"
            :text="$i18n.t('Whether or not to verify SSL when using proxying.')"
          />
        </template>

        <form-group-upstream-api-key namespace="upstream.api_key"
          :column-label="$i18n.t('API Key')"
          :text="$i18n.t('API key to interact with upstream Fingerbank project. Changing this value requires to restart the Fingerbank collector.')"
          :valid-feedback="(fingerbankAccountName) ? $i18n.t('API key is valid.') : undefined"
        />

        <template v-if="!fingerbankAccountName && isApiKey">
          <base-form-group class="mb-3"
            :class="{
              'is-invalid': !fingerbankAccountIsValid
            }">
            <b-button class="col-sm-7 col-lg-5 col-xl-4"
              :variant="(!fingerbankAccountIsValid) ? 'outline-danger' : 'outline-primary'"
              :disabled="isLoading"
              @click="onVerify">{{ $t('Verify') }}</b-button>

            <div v-if="!fingerbankAccountIsValid"
              class="d-block invalid-feedback py-2">{{ $i18n.t('Invalid API key.') }}</div>
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
  BaseFormGroup
} from '@/components/new/'
import {
  FormGroupUpstreamApiKey,
  FormGroupProxyUseProxy,
  FormGroupProxyHost,
  FormGroupProxyPort,
  FormGroupProxyVerifySsl
} from '@/views/Configuration/fingerbank/generalSettings/_components/'

const components = {
  BaseForm,
  BaseFormGroup,

  FormGroupUpstreamApiKey,
  FormGroupProxyUseProxy,
  FormGroupProxyHost,
  FormGroupProxyPort,
  FormGroupProxyVerifySsl
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
  const form = ref({
    proxy: {
      use_proxy: false
    },
    upstream: {}
  })
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

  const isApiKey = computed(() => form.value && form.value.upstream && form.value.upstream.api_key && form.value.upstream.api_key.length > 0)
  watch(() => form.value.upstream, () => {
    fingerbankAccountName.value = null
  }, { deep: true })

  const isProxy = computed(() => form.value && form.value.proxy && form.value.proxy.use_proxy === 'enabled')
  const isProxyMutated = ref(false)
  watch(() => form.value.proxy, () => {
    isProxyMutated.value = true
    fingerbankAccountName.value = null
  }, { deep: true })

  const _isLoadingSettings = ref(false)
  const isLoading = computed(() => _isLoadingSettings.value || $store.getters['$_fingerbank/isGeneralSettingsLoading'])

  const _getAccountInfo = () => {
    _isLoadingSettings.value = true
    return $store.dispatch('$_fingerbank/getGeneralSettings')
      .then(_form => {
        state.value.fingerbank = _form
        const { proxy, upstream, upstream: { api_key = null } = {} } = _form
        form.value = { proxy, upstream }
        if (api_key) {
          return $store.dispatch('$_fingerbank/getAccountInfo').then(({ name }) => {
            fingerbankAccountName.value = name
          })
        }
      })
      .finally(() => {
        _isLoadingSettings.value = false
      })
  }
  _getAccountInfo().finally(() => { // init
    isProxyMutated.value = false // reset after get
  })

  const onVerify = () => {
    _isLoadingSettings.value = true
     const upstreamPromise = () => {
      const { upstream } = form.value
      upstream.quiet = true
      return $store.dispatch('$_fingerbank/setGeneralSettings', { upstream })
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
    if (isProxyMutated.value) { // update proxy first
      const { proxy } = form.value
      proxy.quiet = true
      return $store.dispatch('$_fingerbank/setGeneralSettings', { proxy }).then(() => {
        return upstreamPromise()
      })
    }
    else {
      return upstreamPromise()
    }
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
    isApiKey,
    isProxy,
    isProxyMutated,
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
