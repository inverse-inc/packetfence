<template>
  <base-form
    :form="form"
    :meta="meta"
    :schema="schema"
    :isLoading="isLoading"
  >
    <form-group-identifier namespace="id"
      :column-label="$i18n.t('Traffic Shaping Policy Name')"
      disabled
    />

    <form-group-upload namespace="upload"
      :column-label="$i18n.t('Upload')"
      :text="$i18n.t(`Bandwidth must be in the following format 'nXY' where XY is one of the following KB,MB,GB,TB,PB.`)"
    />

    <form-group-download namespace="download"
      :column-label="$i18n.t('Traffic Shaping Policy Name')"
      :text="$i18n.t(`Bandwidth must be in the following format 'nXY' where XY is one of the following KB,MB,GB,TB,PB.`)"
    />
  </base-form>
</template>
<script>
import { computed } from '@vue/composition-api'
import {
  BaseForm
} from '@/components/new/'
import schemaFn from '../schema'
import {
  FormGroupIdentifier,
  FormGroupUpload,
  FormGroupDownload
} from './'

const components = {
  BaseForm,

  FormGroupIdentifier,
  FormGroupUpload,
  FormGroupDownload
}

export const props = {
  id: {
    type: String
  },
  role: {
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
  isLoading: {
    type: Boolean,
    default: false
  }
}

export const setup = (props) => {
  const schema = computed(() => schemaFn(props))

  return {
    schema
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

