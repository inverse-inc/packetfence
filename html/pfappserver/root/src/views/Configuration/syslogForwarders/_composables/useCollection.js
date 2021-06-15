import { computed, toRefs } from '@vue/composition-api'
import i18n from '@/utils/locale'

export const useItemProps = {
  id: {
    type: String
  },
  syslogForwarderType: {
    type: String
  }
}

import { useDefaultsFromMeta } from '@/composables/useMeta'
export const useItemDefaults = (meta, props) => {
  const {
    syslogForwarderType
  } = toRefs(props)
  return { ...useDefaultsFromMeta(meta), type: syslogForwarderType.value }
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
        return i18n.t('Syslog Entry <code>{id}</code>', { id: id.value })
      case isClone.value:
        return i18n.t('Clone Syslog Entry <code>{id}</code>', { id: id.value })
      default:
        return i18n.t('New Syslog Entry')
    }
  })
}

export const useItemTitleBadge = (props, context, form) => {
  const {
    syslogForwarderType
  } = toRefs(props)
  return computed(() => (syslogForwarderType.value || form.value.type))
}

export { useRouter } from '../_router'

export { useStore } from '../_store'
