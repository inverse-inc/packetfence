<template>
  <b-card no-body>
    <b-card-header class="d-flex align-items-center">
      <h4 class="mb-0 mr-auto" v-html="title" />
      <b-button
        :to="{ name: 'assistant' }"
        tag="router-link"
        variant="outline-primary"
        size="sm"
      >
        <icon name="comments" class="mr-1" />
        {{ $t('Open Dashboard') }}
      </b-button>
    </b-card-header>
    <b-form @submit.prevent="onSave" ref="rootRef">
      <the-form
        :form="form"
        :meta="meta"
        :isLoading="isLoading"
        :isModified="isModified"
        v-bind="$props"
      />
    </b-form>
    <b-card-footer>
      <form-button-bar
        :isLoading="isLoading"
        :isSaveable="isSaveable"
        :isValid="isValid"
        :formRef="rootRef"
        @reset="onReset"
        @save="onSave"
      />
      <base-services
        v-if="services"
        :value="isModified"
        v-bind="services"
        :title="$t('Restart Required')"
        class="mt-3 mb-0"
      />
    </b-card-footer>
  </b-card>
</template>
<script>
import { useViewResource, useViewResourceComponents, useViewResourceProps as props } from '../../_composables/useViewResource'
import { BaseFormButtonBar, BaseServices } from '@/components/new/'
import * as resource from '../_composables/useResource'
import TheForm from './TheForm'

const components = {
  ...useViewResourceComponents,
  FormButtonBar: BaseFormButtonBar,
  BaseServices,
  TheForm,
}

export default {
  name: 'the-view',
  inheritAttrs: false,
  components,
  props,
  setup(props, context) {
    return useViewResource(resource, props, context)
  }
}
</script>
