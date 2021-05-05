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
      :title="$i18n.t('Unhandled source type')"
      icon="question-circle"
    />
  </b-container>
</template>
<script>
import { BaseContainerLoading } from '@/components/new/'
import FormTypeNessus from './FormTypeNessus'
import FormTypeNessus6 from './FormTypeNessus6'
import FormTypeOpenvas from './FormTypeOpenvas'
import FormTypeRapid7 from './FormTypeRapid7'

const components = {
  BaseContainerLoading,

  FormTypeNessus,
  FormTypeNessus6,
  FormTypeOpenvas,
  FormTypeRapid7
}

import { computed, toRefs } from '@vue/composition-api'
import { useFormProps as props } from '../_composables/useForm'

export const setup = (props) => {

  const {
    form
  } = toRefs(props)

  const formType = computed(() => {
    const { type } = form.value || {}
    switch(type) {
      case 'nessus':  return FormTypeNessus // break
      case 'nessus6': return FormTypeNessus6 // break
      case 'openvas': return FormTypeOpenvas // break
      case 'rapid7':  return FormTypeRapid7 // break
      default:        return undefined
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
