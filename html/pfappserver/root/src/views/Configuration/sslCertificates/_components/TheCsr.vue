<template>
  <b-modal v-model="show"
    @shown="reset"
    @hidden="reset"
    size="lg"
  >
    <template v-slot:modal-title>
      <span v-html="title"></span>
    </template>
    <template v-slot:default>
      <b-form v-if="!csr"
        @submit.prevent="onGenerate" ref="formRef">
        <base-form
          :form="form"
          :schema="schema"
          :isLoading="isLoading"
        >
          <form-group-csr-country namespace="country"
            :column-label="$t('Country')"
          />

          <form-group-csr-state namespace="state"
            :column-label="$t('State')"
          />

          <form-group-csr-locality namespace="locality"
            :column-label="$t('Locality')"
          />

          <form-group-csr-organization-name namespace="organization_name"
            :column-label="$t('Organization Name')"
          />

          <form-group-csr-common-name namespace="common_name"
            :column-label="$t('Common Name')"
          />
        </base-form>
      </b-form>
      <b-form-textarea v-else
        ref="csrRef" rows="6" max-rows="17" v-model="csr"/>
    </template>
    <template v-slot:modal-footer class="text-right">
      <b-button class="mr-1" variant="secondary" @click="onHide">{{ $t('Close') }}</b-button>
      <b-button v-if="csr"
        class="mr-1" variant="primary" @click="onClipboard">{{ $t('Copy to clipboard') }}</b-button>
      <b-button v-else
        class="mr-1" variant="primary" :disabled="!isValid" @click="onGenerate">{{ $t('Generate') }}</b-button>
    </template>
  </b-modal>
</template>
<script>
import {
  BaseForm
} from '@/components/new/'
import {
  FormGroupCsrCountry,
  FormGroupCsrState,
  FormGroupCsrLocality,
  FormGroupCsrOrganizationName,
  FormGroupCsrCommonName
} from './'

const components = {
  BaseForm,
  FormGroupCsrCountry,
  FormGroupCsrState,
  FormGroupCsrLocality,
  FormGroupCsrOrganizationName,
  FormGroupCsrCommonName
}

import { useCsr as setup, useCsrProps as props } from '../_composables/useCsr'

export default {
  name: 'the-csr',
  components,
  props,
  setup
}
</script>
