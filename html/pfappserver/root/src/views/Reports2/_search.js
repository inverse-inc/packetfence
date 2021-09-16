import makeSearch from '@/store/factory/search'
import api from './_api'
const { list, ...rest } = api // omit list

export const useSearch = makeSearch('reports', {
  api: { ...rest },
  defaultCondition: () => ({ op: 'and', values: [
    { op: 'or', values: [ {/* BaseSearchInputAdvancedRule Array placeholder, stripped in requestInterceptor */} ] }
  ] })
})