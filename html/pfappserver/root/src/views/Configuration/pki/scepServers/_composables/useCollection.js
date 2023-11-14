import { computed, toRefs } from '@vue/composition-api'
import i18n from '@/utils/locale'

export const useItemProps = {
  id: {
    type: String
  }
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
        return i18n.t('SCEP Server <code>{id}</code>', { id: id.value })
      case isClone.value:
        return i18n.t('Clone SCEP Server <code>{id}</code>', { id: id.value })
      default:
        return i18n.t('New SCEP Server')
    }
  })
}

export const useItemConfirmSave = props => {
  const {
    isClone,
    isNew
  } = toRefs(props)
  return computed(() => !(isNew.value || isClone.value))
}

export const useServices = () => computed(() => {
  return {
    message: i18n.t('Creating or modifying the PKI configuration requires services restart.'),
    services: ['pfpki'],
    k8s_services: ['pfpki']
  }
})

export { useRouter } from '../_router'

export { useStore } from '../_store'

import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'
import makeSearch from '@/store/factory/search'
import api from '../_api'
export const useSearch = makeSearch('pkiScepServers', {
  api,
  columns: [
    {
      key: 'selected',
      thStyle: 'width: 40px;', tdClass: 'text-center',
      locked: true
    },
    {
      key: 'id',
      label: 'Identifier', // i18n defer
      required: true,
      searchable: true,
      sortable: true,
      visible: true
    },
    {
      key: 'name',
      label: 'Name', // i18n defer
      searchable: true,
      sortable: true,
      visible: true
    },
    {
      key: 'url',
      label: 'URL', // i18n defer
      searchable: true,
      sortable: true,
      visible: true
    },
    {
      key: 'buttons',
      class: 'text-right p-0',
      locked: true
    }
  ],
  fields: [
    {
      value: 'id',
      text: i18n.t('Identifier'),
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'name',
      text: i18n.t('Name'),
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'url',
      text: i18n.t('URL'),
      types: [conditionType.SUBSTRING]
    }
  ],
  sortBy: 'id'
})
