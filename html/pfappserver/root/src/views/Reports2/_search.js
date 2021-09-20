import makeSearch from '@/store/factory/search'
import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'
import i18n from '@/utils/locale'
import api from './_api'

export const useSearchFactory = (report, meta) => {
  const { id } = report.value
  const { columns = [], query_fields = [] } = meta.value
  const { list, ...rest } = api // omit list

  return makeSearch(`reports::${id}`, {
    api: { ...rest },
    defaultCondition: () => ({ op: 'and', values: [
      { op: 'or', values: [
        {/* BaseSearchInputAdvancedRule Array placeholder, stripped in requestInterceptor */ }
      ] }
    ] }),
    requestInterceptor: request => {
      // reduce query by slicing empty objects (strip placeholders from defaultCondition)
      //  walk backwards to prevent Array slice from changing future indexes
      for (let o = request.query.values.length - 1; o >= 0; o--) {
        for (let i = request.query.values[o].values.length - 1; i >= 0; i--) {
          if (Object.keys(request.query.values[o].values[i]).length === 0)
            request.query.values[o].values = [ ...request.query.values[o].values.slice(0, i), ...request.query.values[o].values.slice(i + 1, request.query.values[o].values.length) ]
        }
        if (request.query.values[o].values.length === 0)
          request.query.values = [ ...request.query.values.slice(0, o), ...request.query.values.slice(o + 1, request.query.values[o].values.length) ]
      }
      // append id to api request(s)
      return { ...request, id }
    },
    // build search string from query_fields
    useString: searchString => {
      return {
        op: 'and',
        values: [{
          op: 'or',
          values: query_fields.map(field => ({
            field: field.name,
            op: 'contains',
            value: searchString.trim()
          }))
        }]
      }
    },
    columns: [
      {
        key: 'selected',
        thStyle: 'text-align: center; width: 40px;', tdClass: 'text-center',
        locked: true
      },
      ...columns.map(column => {
        const { /*is_node, is_person,*/ name: key, text: label } = column
        return {
          key,
          label,
          searchable: true,
          visible: true
        }
      }),
      {
        key: 'buttons',
        class: 'text-right p-0',
        locked: true
      }
    ],
    fields: query_fields.map(field => {
      const { name: value, text, type } = field
      switch (type) {
        case 'string':
        default:
          return {
            value,
            text: i18n.t(text),
            types: [conditionType.SUBSTRING]
          }
          // break
      }
    })
  })
}
