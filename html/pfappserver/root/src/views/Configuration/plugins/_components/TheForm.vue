<template>
  <base-form
    :form="form"
    :meta="meta"
    :schema="schema"
    :isLoading="isLoading"
  >
    <the-actions v-if="!isNew && !isClone"
      class="mb-3" :plugin="plugin" :collection="collection" :item="form"
    />
    <b-tabs v-if="tabs.length > 1" nav-class="mx-3" content-class="pt-3" card>
      <b-tab v-for="(tab, index) in tabs" :key="index" :title="tab.title">
        <form-field v-for="field in tab.fields" :key="field.key"
          :field="field" :meta="meta" :isNew="isNew" :isClone="isClone"
        />
      </b-tab>
    </b-tabs>
    <template v-else-if="tabs.length === 1">
      <form-field v-for="field in tabs[0].fields" :key="field.key"
        :field="field" :meta="meta" :isNew="isNew" :isClone="isClone"
      />
    </template>
  </base-form>
</template>
<script>
import { BaseForm } from '@/components/new/'
import FormField from './FormField'
import TheActions from './TheActions'

const components = {
  BaseForm,
  FormField,
  TheActions
}

import { computed, toRefs } from '@vue/composition-api'
import { useFormMetaSchema } from '@/composables/useMeta'
import yup from '@/utils/yup'
import { useManifest } from '../_composables/useCollection'

const props = {
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
  },
  id: {
    type: String
  },
  plugin: {
    type: String
  },
  collection: {
    type: String
  }
}

const setup = props => {

  const {
    meta
  } = toRefs(props)

  const manifest = useManifest(props)

  // tabs from the manifest, otherwise all the fields of the OPTIONS meta
  const tabs = computed(() => {
    const { form: { tabs, fields } = {} } = manifest.value
    if (Array.isArray(tabs) && tabs.length)
      return tabs.map(tab => ({ ...tab, fields: tab.fields || [] }))
    if (Array.isArray(fields) && fields.length)
      return [{ fields }]
    return [{
      fields: Object.keys(meta.value || {}).map(key => ({ key, identifier: key === 'id' }))
    }]
  })

  const schema = useFormMetaSchema(meta, computed(() => yup.object()))

  return {
    tabs,
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
