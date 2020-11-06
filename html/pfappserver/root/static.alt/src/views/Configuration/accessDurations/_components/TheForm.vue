<template>
  <base-form
    :form="form"
    :meta="meta"
    :schema="schema"
    :isLoading="isLoading"
  >

    <form-group-access-duration-choices namespace="access_duration_choices"
      :column-label="$i18n.t('Access duration choices')"
      :text="$i18n.t('List of all the choices offered in the access duration action of an authentication source.')"
    />

    <form-group-default-access-duration namespace="default_access_duration"
      :column-label="$i18n.t('Default access duration')"
      :text="$i18n.t('This is the default access duration value selected in the dropdown. The value must be part of the above list of access duration choices.')"
      :options="defaultAccessDurationOptions"
    />

  </base-form>
</template>
<script>
import { computed, toRefs } from '@vue/composition-api'
import {
  BaseForm
} from '@/components/new/'
import schemaFn from '../schema'
import {
  FormGroupAccessDurationChoices,
  FormGroupDefaultAccessDuration
} from './'

const components = {
  BaseForm,

  FormGroupAccessDurationChoices,
  FormGroupDefaultAccessDuration
}

export const props = {
  id: {
    type: String
  },
  form: {
    type: Object
  },
  meta: {
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

  const defaultAccessDurationOptions = computed(() => {
    const { access_duration_choices = [] } = form.value
    return access_duration_choices
  })

  return {
    schema,

    defaultAccessDurationOptions
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

