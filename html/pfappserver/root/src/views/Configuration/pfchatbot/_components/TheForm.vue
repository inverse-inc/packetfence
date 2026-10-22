<template>
  <base-form
    :form="form"
    :meta="meta"
    :schema="schema"
    :isLoading="isLoading"
  >
    <form-group-provider namespace="provider"
                         :column-label="$i18n.t('Provider')"
                         :text="$i18n.t('The LLM provider (bring your own key). Applied without a restart.')"
                         :options="providerOptions"
    />

    <form-group-api-key namespace="api_key"
                        :column-label="$i18n.t('API key')"
                        :text="$i18n.t('The API key for the LLM provider. Test validates it with the provider without saving it.')"
    />

    <form-group-model namespace="model"
                      :column-label="$i18n.t('Model')"
                      :text="$i18n.t('Leave empty for the provider default. Applied without a restart.')"
    />

    <form-group-pf-username namespace="pf_username"
                            :column-label="$i18n.t('PacketFence API username')"
                            :text="$i18n.t('The admin API user the assistant uses to read and change PacketFence data. Requires a restart of the assistant.')"
    />

    <form-group-pf-password namespace="pf_password"
                            :column-label="$i18n.t('PacketFence API password')"
                            :text="$i18n.t('Requires a restart of the assistant.')"
    />

    <form-group-pf-verify-tls namespace="pf_verify_tls"
                              :column-label="$i18n.t('Verify PacketFence API TLS')"
                              :text="$i18n.t('Verify the TLS certificate of the PacketFence API. Requires a restart of the assistant.')"
    />

    <form-group-llm-timeout namespace="llm_timeout"
                            :column-label="$i18n.t('LLM timeout')"
                            :text="$i18n.t('Seconds to wait for a response from the LLM provider. Requires a restart of the assistant.')"
    />

    <form-group-llm-retries namespace="llm_retries"
                            :column-label="$i18n.t('LLM retries')"
                            :text="$i18n.t('Attempts made when the LLM provider is rate limited or unavailable. Requires a restart of the assistant.')"
    />

    <form-group-rag-embed-model namespace="rag_embed_model"
                                :column-label="$i18n.t('Embedding model')"
                                :text="$i18n.t('Indexes the documentation and the API specification. Requires a restart of the assistant.')"
    />

    <form-group-rag-rerank-model namespace="rag_rerank_model"
                                 :column-label="$i18n.t('Reranking model')"
                                 :text="$i18n.t('Leave empty to disable reranking. Requires a restart of the assistant.')"
    />

    <form-group-file-max namespace="file_max"
                         :column-label="$i18n.t('Maximum file size')"
                         :text="$i18n.t('Maximum size of a single file, in MB. Requires a restart of the assistant.')"
    />

    <form-group-file-thread-quota namespace="file_thread_quota"
                                  :column-label="$i18n.t('Conversation quota')"
                                  :text="$i18n.t('Maximum total size of the files of one conversation, in MB. Requires a restart of the assistant.')"
    />

    <form-group-file-user-quota namespace="file_user_quota"
                                :column-label="$i18n.t('Administrator quota')"
                                :text="$i18n.t('Maximum total size of the files of one administrator, in MB. Requires a restart of the assistant.')"
    />

    <form-group-upload-ttl-days namespace="upload_ttl_days"
                                :column-label="$i18n.t('Upload retention')"
                                :text="$i18n.t('Days after which uploaded files are deleted. Requires a restart of the assistant.')"
    />
  </base-form>
</template>
<script>
import {computed} from '@vue/composition-api'
import {BaseForm} from '@/components/new/'
import schemaFn from '../schema'
import {
  FormGroupProvider,
  FormGroupApiKey,
  FormGroupModel,
  FormGroupPfUsername,
  FormGroupPfPassword,
  FormGroupPfVerifyTls,
  FormGroupLlmTimeout,
  FormGroupLlmRetries,
  FormGroupRagEmbedModel,
  FormGroupRagRerankModel,
  FormGroupFileMax,
  FormGroupFileThreadQuota,
  FormGroupFileUserQuota,
  FormGroupUploadTtlDays,
} from './'

const components = {
  BaseForm,

  FormGroupProvider,
  FormGroupApiKey,
  FormGroupModel,
  FormGroupPfUsername,
  FormGroupPfPassword,
  FormGroupPfVerifyTls,
  FormGroupLlmTimeout,
  FormGroupLlmRetries,
  FormGroupRagEmbedModel,
  FormGroupRagRerankModel,
  FormGroupFileMax,
  FormGroupFileThreadQuota,
  FormGroupFileUserQuota,
  FormGroupUploadTtlDays,
}

export const props = {
  form: {
    type: Object
  },
  meta: {
    type: Object
  },
  isLoading: {
    type: Boolean,
    default: false
  }
}

// keys of the assistant's provider registry (lib/pfchatbot/providers)
const providerOptions = ['anthropic', 'openai'].map(value => ({ value, text: value }))

export const setup = (props) => {

  const schema = computed(() => schemaFn(props))

  return {
    schema,
    providerOptions
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
