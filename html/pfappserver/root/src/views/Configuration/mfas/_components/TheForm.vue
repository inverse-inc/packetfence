<template>
  <b-container class="px-0" fluid>
    <component v-if="formType"
      :is="formType" v-bind="$props"
    />

    <base-container-loading v-else-if="isLoading"
      :title="$i18n.t('Building Form')"
      :text="$i18n.t('Hold on a moment while we render it...')"
      spin
    />

    <base-container-loading v-else
      :title="$i18n.t('Unhandled mfa type')"
      icon="question-circle"
    />
  </b-container>
</template>
<script>
import { BaseContainerLoading } from '@/components/new/'
import FormTypeAkamai from './FormTypeAkamai'
import FormTypeTOTP from './FormTypeTOTP'

const components = {
  BaseContainerLoading,

  FormTypeAkamai,
  FormTypeTOTP,
}

import { computed, toRefs, unref } from '@vue/composition-api'
import { useItemProps } from '../_composables/useCollection'
import { useForm, useFormProps } from '../_composables/useForm'

const props = {
  ...useItemProps,
  ...useFormProps
}

export const setup = (props) => {

  const {
    form
  } = toRefs(props)

  const formType = computed(() => {
    const { type } = unref(form)
    switch(type) {
      case 'Akamai':
        return FormTypeAkamai // break
      case 'TOTP':
        return FormTypeTOTP // break
      default:
        return undefined
    }
  })

  return {
    ...useForm(props),

    formType
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
