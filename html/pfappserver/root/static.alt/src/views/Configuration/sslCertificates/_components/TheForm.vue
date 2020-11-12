<template>
  <b-container fluid class="p-0">

    <!--
      View mode (default)
    -->
    <template v-if="!isShowEdit">
      <b-card no-body class="m-3">
        <b-card-header>
          <h5 class="mb-0 d-inline">{{ title }} {{ $t('Certificate') }}</h5>
          <b-button v-t="'Generate Signing Request (CSR)'" class="float-right" size="sm" variant="outline-secondary" @click="doShowCsr"/>
        </b-card-header>
        <b-container fluid>
          <b-row align-v="center" v-if="isLetsEncrypt">
            <b-col sm="3" class="col-form-label"><icon name="check"/></b-col>
            <b-col sm="9">{{ $t(`Use Let's Encrypt`)} }</b-col>
          </b-row>
          <b-row align-v="center" v-if="isCertKeyMatch">
            <b-col sm="3" class="col-form-label"><icon class="text-success" name="circle"/></b-col>
            <b-col sm="9">{{ $t('Certificate/Key match') }}</b-col>
          </b-row>
          <b-row align-v="center" v-else>
            <b-col sm="3" class="col-form-label"><icon class="text-danger fa-overlap" name="circle"/></b-col>
            <b-col sm="9">{{ $t(`Certificate/Key don't match`) }}</b-col>
          </b-row>
          <b-row align-v="center" v-if="isChainValid">
            <b-col sm="3" class="col-form-label"><icon class="text-success" name="circle"/></b-col>
            <b-col sm="9">{{ $t('Chain is valid') }}</b-col>
          </b-row>
          <b-row align-v="center" v-else>
            <b-col sm="3" class="col-form-label"><icon class="text-danger fa-overlap" name="circle"/></b-col>
            <b-col sm="9">{{ $t('Chain is invalid') }}</b-col>
          </b-row>
          <b-row align-v="baseline" v-for="(value, key) in certificateLocale" :key="key">
            <b-col sm="3" class="col-form-label">{{ key }}</b-col>
            <b-col sm="9">{{ value }}</b-col>
          </b-row>
        </b-container>
      </b-card>

      <b-card no-body class="m-3" v-if="isCertificateAuthority">
        <b-card-header>
          <h4 class="mb-0">{{ title }} {{ $t('Certificate Authorities') }}</h4>
        </b-card-header>
        <b-container fluid>
          <b-row align-v="baseline" v-for="(value, key) in certificateAuthorityLocale" :key="key">
            <b-col sm="3" class="col-form-label">{{ key }}</b-col>
            <b-col sm="9">{{ value }}</b-col>
          </b-row>
        </b-container>
      </b-card>

      <b-card-footer>
        <b-button v-t="'Edit'" @click="doShowEdit"/>
      </b-card-footer>
    </template>

    <!--
      Edit mode
    -->
    <template v-else>
      <b-alert :show="showAlert" class="m-3" variant="warning" fade>
        <h4 class="alert-heading" v-t="'Warning'"/>
        <p>
          {{ $t('Some services must be restarted to load the new certificate.') }}
          <span v-if="id === 'http'" v-html="$t('The <strong>{service}</strong> service needs to be restarted from the command-line.', { service: 'haproxy-admin' })"></span>
        </p>
        <button-service v-for="service in services" :key="service"
          :service="service"
          class="mr-1"
          restart start stop
        />
      </b-alert>

      <base-form
        :form="form.certificate"
        :schema="schema"
        :isLoading="isLoading"
        class="p-3"
      >
        <form-group-lets-encrypt namespace="lets_encrypt"
          :column-label="$i18n.t(`Use Let's Encrypt`)"
        />

        <!--
          With Let's Encrypt (lets_encrypt: true)
        -->
        <template v-if="form.lets_encrypt">
Yes
        </template>

        <!--
          Without Let's Encrypt (lets_encrypt: false)
        -->
        <template v-else>

          <form-group-certificate namespace="certificate"
            :column-label="$i18n.t('Certificate')"
            rows="6" max-rows="6"
          />

          <form-group-private-key namespace="private_key"
            :column-label="$i18n.t('Private Key')"
            rows="6" max-rows="6"
          />

          <form-group-check-chain namespace="check_chain"
            :column-label="$i18n.t('Validate certificate chain')"
          />

          <form-group-find-intermediate-cas v-model="isFindIntermediateCas"
            :column-label="$i18n.t('Find intermediate CA certificates automatically')"
          />

        </template>
      </base-form>

<base-button-upload
  @files="testFiles" @focus="testFocus" @input="testInput" accept="text/*" read-as-text
  class="btn btn-outline-primary"
/>
<pre>{{ {form} }}</pre>

      <b-card-footer>
        <b-button v-t="'Cancel'" @click="doHideEdit"></b-button>
      </b-card-footer>
    </template>

    <!--
      CSR modal
    -->
    <the-csr
      v-model="isShowCsr"
      :id="id"
      @hidden="doHideCsr"
/>

  </b-container>
</template>
<script>
import {
                        BaseButtonUpload,


  BaseForm,
  BaseFormGroupToggleFalseTrue as FormGroupFindIntermediateCas
} from '@/components/new/'
import {
  ButtonService,
  FormGroupCertificate,
  FormGroupCheckChain,
  FormGroupLetsEncrypt,
  FormGroupPrivateKey,
  TheCsr
} from './'

const components = {
                        BaseButtonUpload,
  BaseForm,
  ButtonService,
  FormGroupCertificate,
  FormGroupCheckChain,
  FormGroupLetsEncrypt,
  FormGroupPrivateKey,
  FormGroupFindIntermediateCas,

  TheCsr
}

import { useForm, useFormProps as props } from '../_composables/useForm'
import { ref } from '@vue/composition-api'

const setup = (props, context) => {

  // cosmetic props only
  const isFindIntermediateCas = ref(false)

  return {
    ...useForm(props, context),

    isFindIntermediateCas,
    testFiles: (...args) => {
      console.log('testFiles', JSON.stringify({args}, null, 2))
    },
    testFocus: (...args) => {
      console.log('testFocus', JSON.stringify({args}, null, 2))
    },
    testInput: (...args) => {
      console.log('testInput', JSON.stringify({args}, null, 2))
    }
  }
}

export default {
  name: 'the-form',
  components,
  props,
  setup
}
</script>

