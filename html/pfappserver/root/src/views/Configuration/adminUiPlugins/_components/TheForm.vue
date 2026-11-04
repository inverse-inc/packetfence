<template>
  <base-form
    :form="form"
    :meta="meta"
    :schema="schema"
    :isLoading="isLoading"
  >
    <form-group-identifier namespace="id"
      :column-label="$i18n.t('Plugin')"
      :text="$i18n.t('Identifier of the plugin. Its API is reachable under /api/v1/plugins/<plugin>/.')"
      :disabled="!isNew && !isClone"
    />

    <form-group-enabled namespace="enabled"
      :column-label="$i18n.t('Enabled')"
    />

    <form-group-description namespace="description"
      :column-label="$i18n.t('Description')"
    />

    <form-group-upstream namespace="upstream"
      :column-label="$i18n.t('Upstream')"
      :text="$i18n.t('Base URL of the plugin API, as reachable from the api-frontend. Requests to /api/v1/plugins/<plugin>/<path> are sent to <upstream>/<path>.')"
    />

    <form-group-manifest namespace="manifest"
      :column-label="$i18n.t('Manifest')"
      :text="$i18n.t('JSON description of the admin UI section of the plugin. Leave empty to use the manifest served by the plugin at <upstream>/admin-ui.')"
      accept="application/json,.json"
      rows="3"
      auto-fit
    />

    <b-form-group v-if="!isNew && !isClone" label-cols="3" class="mb-3">
      <b-button size="sm" variant="outline-primary" :disabled="isTesting" @click="onTest">
        <icon v-if="isTesting" name="circle-notch" spin class="mr-1" />
        {{ $i18n.t('Fetch the manifest from the plugin') }}
      </b-button>
      <b-alert v-if="testResult" class="mt-2 mb-0" :variant="testResult.variant" show>
        {{ testResult.message }}
        <pre v-if="testResult.manifest" class="mt-2 mb-0" style="white-space: pre-wrap; max-height: 20em;">{{ testResult.manifest }}</pre>
        <b-button v-if="testResult.manifest" size="sm" variant="outline-primary" class="mt-2" @click="onUseManifest">{{ $i18n.t('Use this manifest') }}</b-button>
      </b-alert>
    </b-form-group>

    <form-group-acl namespace="acl"
      :column-label="$i18n.t('Admin role actions')"
      :text="$i18n.t('Admin role actions required to use the plugin: <acl>_READ to see it, <acl>_CREATE, <acl>_UPDATE and <acl>_DELETE to change it.')"
    />

    <form-group-replaces namespace="replaces"
      :column-label="$i18n.t('Replaces')"
      :text="$i18n.t('Static section of the admin UI hidden while the plugin is available (ex: connectors).')"
    />

    <form-group-config-files namespace="config_files"
      :column-label="$i18n.t('Configuration files')"
      :text="$i18n.t('Configuration files written by the plugin, as <file>.conf:<pfconfig namespace>. The plugin commits them with POST /api/v1/config/admin_ui_plugin/<plugin>/commit.')"
      :button-label="$i18n.t('Add configuration file')"
    />
  </base-form>
</template>
<script>
import { BaseForm } from '@/components/new/'
import {
  FormGroupAcl,
  FormGroupConfigFiles,
  FormGroupDescription,
  FormGroupEnabled,
  FormGroupIdentifier,
  FormGroupManifest,
  FormGroupReplaces,
  FormGroupUpstream
} from './'

const components = {
  BaseForm,

  FormGroupAcl,
  FormGroupConfigFiles,
  FormGroupDescription,
  FormGroupEnabled,
  FormGroupIdentifier,
  FormGroupManifest,
  FormGroupReplaces,
  FormGroupUpstream
}

import { ref, toRefs } from '@vue/composition-api'
import i18n from '@/utils/locale'
import api from '../_api'
import { useForm, useFormProps as props } from '../_composables/useForm'

const setup = (props, context) => {

  const {
    form,
    id
  } = toRefs(props)

  const { schema } = useForm(props, context)

  const isTesting = ref(false)
  const testResult = ref(null)

  const onTest = () => {
    isTesting.value = true
    testResult.value = null
    api.manifest(id.value)
      .then(manifest => {
        testResult.value = {
          variant: 'success',
          message: i18n.t('The plugin answered with its manifest.'),
          manifest: JSON.stringify(manifest, null, 2)
        }
      })
      .catch(err => {
        const { response: { data: { message } = {} } = {} } = err || {}
        testResult.value = {
          variant: 'danger',
          message: message || i18n.t('The plugin does not answer. Save the plugin before testing it.')
        }
      })
      .finally(() => {
        isTesting.value = false
      })
  }

  const onUseManifest = () => {
    form.value.manifest = testResult.value.manifest
  }

  return {
    schema,
    isTesting,
    testResult,
    onTest,
    onUseManifest
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
