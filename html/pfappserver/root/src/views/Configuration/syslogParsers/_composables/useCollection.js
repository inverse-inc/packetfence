import { computed, toRefs } from '@vue/composition-api'
import i18n from '@/utils/locale'

export const useItemProps = {
  id: {
    type: String
  },
  syslogParserType: {
    type: String
  }
}

import { useDefaultsFromMeta } from '@/composables/useMeta'
export const useItemDefaults = (meta, props) => {
  const {
    syslogParserType
  } = toRefs(props)
  return { ...useDefaultsFromMeta(meta), type: syslogParserType.value }
}

export const useItemTitle = (props) => {
  const {
    id,
    isClone,
    isNew
  } = toRefs(props)
  return computed(() => {
    switch (true) {
      case !isNew.value && !isClone.value:
        return i18n.t('Syslog Parser <code>{id}</code>', { id: id.value })
      case isClone.value:
        return i18n.t('Clone Syslog Parser <code>{id}</code>', { id: id.value })
      default:
        return i18n.t('New Syslog Parser')
    }
  })
}

export const useItemTitleBadge = (props, context, form) => {
  const {
    syslogParserType
  } = toRefs(props)
  return computed(() => (syslogParserType.value || form.value.type))
}

export { useRouter } from '../_router'

export { useStore } from '../_store'
