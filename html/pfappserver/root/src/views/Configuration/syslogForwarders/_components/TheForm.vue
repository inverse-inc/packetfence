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
      :title="$i18n.t('Unhandled syslog forwarder type')"
      icon="question-circle"
    />
  </b-container>
</template>
<script>
import { computed, toRefs, unref } from '@vue/composition-api'
import { useFormProps as props } from '../_composables/useForm'
import { BaseContainerLoading } from '@/components/new/'
import FormTypeFile from './FormTypeFile'
import FormTypeServer from './FormTypeServer'

const components = {
  BaseContainerLoading,

  FormTypeFile,
  FormTypeServer
}

export const setup = (props) => {

  const {
    form
  } = toRefs(props)

  const formType = computed(() => {
    const { type } = unref(form)
    switch(unref(type)) {
      case 'file':
        return FormTypeFile // break
      case 'server':
        return FormTypeServer // break
      default:
        return undefined
    }
  })

  return {
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
