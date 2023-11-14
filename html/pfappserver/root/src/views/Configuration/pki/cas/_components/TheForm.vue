<template>
  <base-form
    :form="form"
    :schema="schema"
    :isLoading="isLoading"
  >
    <b-tabs>
      <base-form-tab :title="$i18n.t('General')" active>
        <the-form-fields v-bind="{ form, isNew, isClone, isLoading }" />
      </base-form-tab>
      <template #tabs-end v-if="!isNew && !isClone">
        <div class="text-right mr-3 mb-1">
          <button-ca-resign
            :id="id" :form="form" class="my-1 mr-1" @change="updateForm" />
          <button-ca-generate-csr
            :id="id" :form="form" class="my-1 mr-1" />
        </div>
      </template>
    </b-tabs>
  </base-form>
</template>
<script>
import { computed, toRefs } from '@vue/composition-api'
import { BaseForm, BaseFormTab } from '@/components/new/'
import schemaFn from '../schema'
import {
  ButtonCaResign,
  ButtonCaGenerateCsr,
} from './'
import TheFormFields from './TheFormFields'

const components = {
  BaseForm,
  BaseFormTab,
  ButtonCaResign,
  ButtonCaGenerateCsr,
  TheFormFields,
}

export const props = {
  id: {
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

export const setup = (props) => {

  const {
    form
  } = toRefs(props)

  const schema = computed(() => schemaFn(props))

  const updateForm = item => {
    form.value = item
  }

  return {
    schema,
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

