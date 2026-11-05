<template>
  <base-form v-if="manifest"
    :form="form"
    :meta="meta"
    :schema="schema"
    :isLoading="isLoading"
  >
    <b-tabs v-if="tabs.length">
      <base-form-tab v-for="(tab, index) in tabs" :key="index" :title="t(tab.title)" :active="index === 0">
        <template v-for="field in tab.fields">
          <component v-if="isVisible(field)" :key="field.namespace" :is="components[field.component]" v-bind="bind(field)" />
        </template>
      </base-form-tab>
    </b-tabs>
    <template v-else>
      <template v-for="field in fields">
        <component v-if="isVisible(field)" :key="field.namespace" :is="components[field.component]" v-bind="bind(field)" />
      </template>
    </template>
  </base-form>
</template>
<script>
/**
 * The form of a plugin page (the-form of the core views), built from the
 * manifest `form` with the core components only (../registry.js).
 */
import { computed } from '@vue/composition-api'
import { BaseForm, BaseFormTab } from '@/components/new/'
import { useFormMetaSchema } from '@/composables/useMeta'
import i18n from '@/utils/locale'
import { components } from '../registry'
import { escapeHtml, formSchema, isFieldVisible, translate, usePlugin } from '../'
import { can } from '../acl'

export const props = {
  pluginId: {
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
  },
  id: {
    type: String
  }
}

export const setup = props => {
  const manifest = computed(() => {
    const plugin = usePlugin(props.pluginId)
    return plugin && plugin.manifest
  })
  // translations follow the UI language
  const t = text => translate(text, i18n.locale)

  const fields = computed(() => (manifest.value && manifest.value.form.fields) || [])
  // a tab whose can the admin does not have is not shown
  const tabs = computed(() => ((manifest.value && manifest.value.form.tabs) || []).filter(tab => can(tab.can)))
  // the manifest validators, merged with the meta of the API OPTIONS like the core forms
  const schema = computed(() => manifest.value && useFormMetaSchema(computed(() => props.meta || {}), computed(() => formSchema(manifest.value))))

  const isVisible = field => isFieldVisible(field, props.form || {})
  const bind = field => ({
    ...(field.props || {}),
    namespace: field.namespace,
    columnLabel: t(field.label),
    text: escapeHtml(t(field.text)), // rendered with v-html by the core components
    placeholder: t(field.placeholder),
    // the identifier of an existing item cannot change
    ...((field.namespace === 'id' && !props.isNew && !props.isClone) ? { disabled: true } : {})
  })

  return {
    manifest,
    fields,
    tabs,
    schema,
    isVisible,
    bind,
    t,
    components
  }
}

// @vue/component
export default {
  name: 'the-form',
  inheritAttrs: false,
  components: {
    BaseForm,
    BaseFormTab
  },
  props,
  setup
}
</script>
