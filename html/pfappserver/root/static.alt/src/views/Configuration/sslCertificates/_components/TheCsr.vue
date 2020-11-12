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

    <!--
      <b-form @submit.prevent="generateCSR($event)" v-show="!csr">
        <pf-form-chosen :label-cols="6" :column-label="$t('Country')" ref="csr_country" v-model="$v.csrForm.country.$model" :vuelidate="$v.csrForm.country" :options="countries" />
        <pf-form-input :label-cols="6" :column-label="$t('State')" v-model="$v.csrForm.state.$model" :vuelidate="$v.csrForm.state" />
        <pf-form-input :label-cols="6" :column-label="$t('Locality')" v-model="$v.csrForm.locality.$model" :vuelidate="$v.csrForm.locality" />
        <pf-form-input :label-cols="6" :column-label="$t('Organization Name')" v-model="$v.csrForm.organization_name.$model" :vuelidate="$v.csrForm.organization_name" />
        <pf-form-input :label-cols="6" :column-label="$t('Common Name')" v-model="$v.csrForm.common_name.$model" :vuelidate="$v.csrForm.common_name" />
      </b-form>
      <b-form-textarea ref="csr" rows="6" max-rows="17" v-show="csr" v-model="csr"></b-form-textarea>
    -->
    </template>
    <template v-slot:modal-footer class="text-right">
      <b-button class="mr-1" variant="secondary" @click="doHide">{{ $t('Close') }}</b-button>
      <!--
      <b-button v-if="csr" class="mr-1" variant="primary" :disabled="$v.csrForm.$invalid" @click="clipboardCSR($event)">{{ $t('Copy to clipboard') }}</b-button>
      <b-button v-else class="mr-1" variant="primary" :disabled="$v.csrForm.$invalid" @click="generateCSR($event)">{{ $t('Generate') }}</b-button>
      -->
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
