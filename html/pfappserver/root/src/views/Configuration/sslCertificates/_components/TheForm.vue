<template>
  <b-tabs v-model="tabIndex" card>

    <!--
      View mode (default)
    -->
    <b-tab :title="$t('View {title} Certificates', { title })" class="p-0">
      <b-card no-body class="m-3">
        <b-card-header>
          <h5 class="mb-0 d-inline">{{ title.value }} {{ $t('Certificate') }}</h5>
          <b-button v-t="'Generate Signing Request (CSR)'" class="float-right" size="sm" variant="outline-secondary" @click="doShowCsr"/>
        </b-card-header>
        <base-container-loading v-if="isLoading"
          :title="$i18n.t('Loading Certificate')"
          spin
        />
        <b-container fluid v-else>
          <b-row align-v="center" v-if="isLetsEncrypt">
            <b-col sm="3" class="col-form-label"><icon name="check"/></b-col>
            <b-col sm="9">{{ $t(`Use Let's Encrypt`) }}</b-col>
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
      <template v-if="form.info">
        <b-card v-for="(intermediate_ca, index) in intermediateCertificatesLocale" :key="intermediate_ca.serial"
          no-body class="m-3">
          <b-card-header>
            <h4 class="mb-0 d-inline">{{ title }} {{ $t('Intermediate CA certificate') }}</h4>
            <b-badge variant="secondary" class="ml-1">{{ index + 1 }}</b-badge>
          </b-card-header>
          <b-row align-v="center" v-for="(value, key) in intermediate_ca" :key="key">
              <b-col sm="3" class="col-form-label">{{ key }}</b-col>
              <b-col sm="9" v-if="Array.isArray(value)">
                <b-badge v-for="(v, k) in value" :key="`${key}-${k}`" class="mr-1" variant="secondary">{{ v }}</b-badge>
              </b-col>
            <b-col sm="9" v-else>{{ value }}</b-col>
          </b-row>
        </b-card>
      </template>
      <b-card no-body class="m-3" v-if="isCertificationAuthority">
        <b-card-header>
<<<<<<< HEAD
          <h4 class="mb-0">{{ title.value }} {{ $t('Certification Authority Certificates') }}</h4>
=======
          <h4 class="mb-0">{{ title }} {{ $t('Certification Authority Certificate(s)') }}</h4>
>>>>>>> f6a4cdb5fe... fix(admin(vue,js)): add split tab view in ssl certificates, fixes #6806
        </b-card-header>
        <base-container-loading v-if="isLoading"
          :title="$i18n.t('Loading Certification Authority Certificates')"
          spin
        />
        <template v-else>
          <b-container v-for="(ca, index) in certificationAuthorityLocale" :key="index"
            class="mb-3" :class="{ 'border-top': index }" fluid>
            <b-row align-v="center" v-for="(value, key) in ca" :key="key">
              <b-col sm="3" class="col-form-label">{{ key }}</b-col>
              <b-col sm="9">{{ value }}</b-col>
            </b-row>
          </b-container>
        </template>
      </b-card>
      <template v-if="form.info">
        <b-card v-for="(intermediate_ca, index) in form.info.intermediate_cas" :key="intermediate_ca.serial"
          no-body class="m-3">
          <b-card-header>
            <h4 class="mb-0 d-inline">{{ title.value }} {{ $t('Intermediate') }}</h4>
            <b-badge variant="secondary" class="ml-1">{{ index + 1 }}</b-badge>
          </b-card-header>
          <b-row align-v="center" v-for="(value, key) in intermediate_ca" :key="key">
            <b-col sm="3" class="col-form-label">{{ key }}</b-col>
            <b-col sm="9">{{ value }}</b-col>
          </b-row>
        </b-card>
      </template>
      <b-card-footer>
        <b-button v-t="'Edit'" @click="tabIndex.value = 1"/>
      </b-card-footer>
    </b-tab>

    <!--
      Edit mode
    -->
    <b-tab :title="$t('Edit {title} Certificates', { title })" class="p-0">
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
          <template v-if="form.certificate && form.certificate.lets_encrypt">
            <form-group-lets-encrypt-common-name namespace="common_name"
              :column-label="$i18n.t('Common Name')"
            />

            <form-group-ca v-if="id === 'radius'"
              namespace="ca"
              :column-label="$i18n.t('Certification Authority certificate(s)')"
              rows="6" auto-fit
            />
          </template>

          <!--
            Without Let's Encrypt (lets_encrypt: false)
          -->
          <template v-else>
            <form-group-certificate namespace="certificate"
              :column-label="$i18n.t('Certificate')"
              rows="6" auto-fit
            />

            <form-group-ca v-if="id === 'radius'"
              namespace="ca"
              :column-label="$i18n.t('Certification Authority certificate(s)')"
              rows="6" auto-fit
            />

            <form-group-private-key namespace="private_key"
              :column-label="$i18n.t('Private Key')"
              rows="6" auto-fit
            />

            <form-group-check-chain namespace="check_chain"
              :column-label="$i18n.t('Validate certificate chain')"
            />

            <form-group-find-intermediate-cas v-model="isFindIntermediateCas"
              :column-label="$i18n.t('Find intermediate CA certificates automatically')"
            />

            <form-group-intermediate-certification-authorities v-if="!isFindIntermediateCas"
              namespace="intermediate_cas"
              :column-label="$i18n.t('Intermediate CA certificate(s)')"
            />
          </template>
        </base-form>
      </b-form>
      <b-card-footer>
        <alert-services :show="isModified" :disabled="isLoading" :services="services" />
        <base-form-button-bar
          :action-key="actionKey"
          :action-key-button-verb="$i18n.t('View')"
          :is-loading="isLoading"
          :is-saveable="true"
          :is-valid="isValid"
          :form-ref="rootRef"
          @close="tabIndex = 0"
          @reset="onReset"
          @save="onSaveWrapper"
        />
      </b-card-footer>
    </b-tab>

    <!--
      CSR modal
    -->
    <the-csr
      v-model="isShowCsr"
      :id="id"
      @hidden="doHideCsr"
    />
  </b-tabs>
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
  FormGroupCa,
  FormGroupCertificate,
  FormGroupCheckChain,
  FormGroupIntermediateCertificationAuthorities,
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
  FormGroupCa,
  FormGroupCertificate,
  FormGroupCheckChain,
  FormGroupFindIntermediateCas,
  FormGroupIntermediateCertificationAuthorities,
  FormGroupLetsEncrypt,
  FormGroupLetsEncryptCommonName,
  FormGroupPrivateKey,

  TheCsr
}

import { computed, ref, toRefs } from '@vue/composition-api'
import { useForm, useFormProps } from '../_composables/useForm'
import { useViewCollectionItemFixed, useViewCollectionItemFixedProps } from '../../_composables/useViewCollectionItemFixed'
import * as collection from '../_composables/useCollection'

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
    actionKey,
    schema,
    certificateLocale,
    certificationAuthorityLocale,
    intermediateCertificatesLocale,
    services,

    isShowCsr,
    doShowCsr,
    doHideCsr,

    isCertificationAuthority,
    isCertKeyMatch,
    isChainValid,
    isLetsEncrypt,
    isFindIntermediateCas
  } = useForm(form, props, context)

  const { root: { $store } = {} } = context

  const onSaveWrapper = () => {
    const closeAfter = actionKey.value
    onSave()
      .then(() => {
          const { useStore } = collection
          const { getItem } = useStore($store)
          getItem(form.value.certificate)
            .then(item => form.value = item)
            .finally(() => {
              if (closeAfter)
                tabIndex.value = 0
            })
      })
  }

  const tabIndex = ref(0)

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

    // useForm
    actionKey,
    schema,
    certificateLocale,
    certificationAuthorityLocale,
    intermediateCertificatesLocale,
    services,
    isShowCsr,
    doShowCsr,
    doHideCsr,
    isCertificationAuthority,
    isCertKeyMatch,
    isChainValid,
    isLetsEncrypt,
    isFindIntermediateCas,

    // custom
    onSaveWrapper,
    tabIndex
  }
}

export default {
  name: 'the-form',
  components,
  props,
  setup
}
</script>
