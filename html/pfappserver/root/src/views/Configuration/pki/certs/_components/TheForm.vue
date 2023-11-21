<template>
  <base-form
    :form="form"
    :schema="schema"
    :isLoading="isLoading"
    :isReadonly="!isNew && !isClone"
  >
    <b-tabs>
      <base-form-tab :title="$i18n.t('General')" active>
        <the-form-fields v-bind="{ form, isNew, isClone, isLoading }" />
      </base-form-tab>
      <template #tabs-end v-if="!isNew && !isClone">
        <div class="text-right mr-3 mb-1">
          <button-certificate-copy
            :disabled="!isServiceAlive" :id="id" class="my-1 mr-1" />
          <button-certificate-download v-if="!form.scep || !form.csr"
            :disabled="!isServiceAlive" :id="id" class="my-1 mr-1" />
          <button-certificate-email v-if="!form.scep || !form.csr"
            :disabled="!isServiceAlive" :id="id" class="my-1 mr-1" />
          <button-certificate-resign
            :disabled="!isServiceAlive" :id="id" :form="form" class="my-1 mr-1" @change="updateForm" />
          <button-certificate-revoke
            :disabled="!isServiceAlive" :id="id" class="my-1 mr-1" />
        </div>
      </template>
    </b-tabs>
  </base-form>
</template>
<script>
import { computed } from '@vue/composition-api'
import { BaseForm, BaseFormTab } from '@/components/new/'
import schemaFn from '../schema'
import {
  ButtonCertificateCopy,
  ButtonCertificateDownload,
  ButtonCertificateEmail,
  ButtonCertificateRevoke,
  ButtonCertificateResign
} from './'
import TheFormFields from './TheFormFields'

const components = {
  BaseForm,
  BaseFormTab,
  ButtonCertificateCopy,
  ButtonCertificateDownload,
  ButtonCertificateEmail,
  ButtonCertificateRevoke,
  ButtonCertificateResign,
  TheFormFields
}

export const props = {
  id: {
    type: String
  },
  profile_id: {
    type: String
  },
  form: {
    type: Object
  },
  isNew: {
    type: Boolean,
    default: false
  },
  isClone: {
    type: Boolean,
    default: false
  },
  isLoading: {
    type: Boolean,
    default: false
  }
}

export const setup = (props, context) => {

  const schema = computed(() => schemaFn(props))

  const { emit, root: { $store } = {} } = context

  const isServiceAlive = computed(() => {
    if ($store.getters['system/isSaas']) {
      const { pfpki: { available = false } = {} } = $store.getters['k8s/services']
      return available
    }
    else if ($store.getters['cluster/servicesByServer']) {
      const { pfpki: { hasAlive = false } = {} } = $store.getters['cluster/servicesByServer']
      return hasAlive
    }
    return false
  })

  const updateForm = item => {
    emit('form', item)
  }

  return {
    schema,
    isServiceAlive,
    updateForm
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

