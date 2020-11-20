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
        <base-container-loading v-if="isLoading"
          :title="$i18n.t('Loading Certificate')"
          spin
        />
        <b-container fluid v-else>
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
        <base-container-loading v-if="isLoading"
          :title="$i18n.t('Loading Certificate Authorities')"
          spin
        />
        <b-container fluid v-else>
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
      <b-form @submit.prevent="onSave" ref="rootRef">
        <base-form
          :form="form.certificate"
          :schema="schema"
          :isLoading="isLoading"
        >
          <form-group-lets-encrypt namespace="lets_encrypt"
            :column-label="$i18n.t(`Use Let's Encrypt`)"
          />

          <!--
            With Let's Encrypt (lets_encrypt: true)
          -->
          <template v-if="form.certificate.lets_encrypt">
            <form-group-lets-encrypt-common-name namespace="common_name"
              :column-label="$i18n.t('Common Name')"
            />
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

            <form-group-intermediate-certificate-authorities v-if="!isFindIntermediateCas"
              namespace="intermediate_cas"
              :column-label="$i18n.t('Intermediate CA certificate(s)')"
            />
          </template>
        </base-form>
      </b-form>

      <b-card-footer>
        <alert-services :show="isModified" :disabled="isLoading" :services="services" />
        <base-form-button-bar
          :isLoading="isLoading"
          :isValid="isValid"
          :formRef="rootRef"
          @close="doHideEdit"
          @reset="onReset"
          @save="onSave"
        />
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
  BaseContainerLoading,
  BaseForm,
  BaseFormButtonBar,
  BaseFormGroupToggleFalseTrue as FormGroupFindIntermediateCas
} from '@/components/new/'
import {
  AlertServices,
  FormGroupCertificate,
  FormGroupCheckChain,
  FormGroupIntermediateCertificateAuthorities,
  FormGroupLetsEncrypt,
  FormGroupLetsEncryptCommonName,
  FormGroupPrivateKey,
  TheCsr
} from './'

const components = {
  AlertServices,
  BaseContainerLoading,
  BaseForm,
  BaseFormButtonBar,
  FormGroupCertificate,
  FormGroupCheckChain,
  FormGroupFindIntermediateCas,
  FormGroupIntermediateCertificateAuthorities,
  FormGroupLetsEncrypt,
  FormGroupLetsEncryptCommonName,
  FormGroupPrivateKey,

  TheCsr
}
import { useForm, useFormProps } from '../_composables/useForm'
import { useViewCollectionItemFixed, useViewCollectionItemFixedProps } from '../../_composables/useViewCollectionItemFixed'
import collection from '../_composables/useCollection'

const props = {
  ...useFormProps,
  ...useViewCollectionItemFixedProps,
}

const setup = (props, context) => {

  const {
    rootRef,
    form,
    title,
    isModified,
    customProps,
    isValid,
    isLoading,
    onReset,
    onSave,
  } = useViewCollectionItemFixed(collection, props, context)

  const {
    schema,
    certificateLocale,
    certificateAuthorityLocale,
    services,

    isShowEdit,
    doShowEdit,
    doHideEdit,

    isShowCsr,
    doShowCsr,
    doHideCsr,

    isCertificateAuthority,
    isCertKeyMatch,
    isChainValid,
    isLetsEncrypt,
    isFindIntermediateCas
  } = useForm(form, props, context)

  return {
    // useViewCollectionItemFixed
    rootRef,
    form,
    meta: undefined,
    title,
    isModified,
    customProps,
    isValid,
    isLoading,
    onReset,
    onSave,

    // useForm
    schema,
    certificateLocale,
    certificateAuthorityLocale,
    services,
    isShowEdit,
    doShowEdit,
    doHideEdit,
    isShowCsr,
    doShowCsr,
    doHideCsr,
    isCertificateAuthority,
    isCertKeyMatch,
    isChainValid,
    isLetsEncrypt,
    isFindIntermediateCas,
  }
}

export default {
  name: 'the-form',
  components,
  props,
  setup
}
</script>
