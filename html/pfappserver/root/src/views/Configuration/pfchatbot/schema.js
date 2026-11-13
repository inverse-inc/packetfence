import i18n from '@/utils/locale'
import yup from '@/utils/yup'

export default () => {
  return yup.object().shape({
    provider: yup.string().nullable(),
    api_key: yup.string().nullable()
      .when('provider', {
        is: provider => !!provider,
        then: yup.string().nullable().required(i18n.t('API key is required when a provider is selected.')),
        otherwise: yup.string().nullable()
      }),
    model: yup.string().nullable(),
    pf_username: yup.string().nullable(),
    pf_password: yup.string().nullable(),
    llm_timeout: yup.string().nullable().minAsInt(1),
    llm_retries: yup.string().nullable().minAsInt(1),
    rag_embed_model: yup.string().nullable(),
    rag_rerank_model: yup.string().nullable(),
    file_max: yup.string().nullable().minAsInt(1),
    file_thread_quota: yup.string().nullable().minAsInt(1),
    file_user_quota: yup.string().nullable().minAsInt(1),
    upload_ttl_days: yup.string().nullable().minAsInt(1)
  })
}
