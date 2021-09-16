<template>
  <b-card no-body>
    <b-card-header>
      <h4 class="mb-0" v-html="id" />
      <p v-if="description"
        v-html="description" class="mt-3 mb-0" />
    </b-card-header>
    <div class="card-body" v-if="search">
      <base-search
        :use-search="useSearch" />
      <b-table ref="tableRef" :key="uuid"
        :busy="isLoading"
        :hover="items.length > 0"
        :items="search.items"
        :fields="visibleColumns"
        class="mb-0"
        show-empty
        no-local-sorting
        fixed
        striped
        selectable
      >

      </b-table>
<!--
        @row-clicked="goToItem"
        @row-selected="onRowSelected"

-->

    </div>

    <pre>{{ search }}</pre>
    <pre>{{ {report, meta, id, hasCursor, hasDateRange } }}</pre>

  </b-card>
</template>

<script>
import {
  BaseSearch,
  BaseSearchInputColumns,
  BaseTableEmpty
} from '@/components/new/'
const components = {
  BaseSearch,
  BaseSearchInputColumns,
  BaseTableEmpty
}

const props = {
  id: {
    type: String
  }
}

import { computed, ref, toRefs, watch } from '@vue/composition-api'
import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'
import i18n from '@/utils/locale'
import { useSearch } from '../_search'
import { useStore } from '../_store'

const setup = (props, context) => {

  const {
    id
  } = toRefs(props)

  const { root: { $store } = {} } = context

  const {
    getItem,
    getItemOptions
  } = useStore($store)

  const report = ref()
  const meta = ref()

  const search = useSearch()

  watch(id, () => {
    report.value = {}
    meta.value = {}
    let promises = []
    promises[promises.length] = getItem({ id: id.value }).then(item => {
      report.value = item
    })
    promises[promises.length] = getItemOptions({ id: id.value }).then(options => {
      const { report_meta = {} } = options
      meta.value = report_meta
    })
    Promise.all(promises).finally(() => {
      const { columns = [], query_fields = [] } = meta.value
      search.requestInterceptor = request => {
        // reduce query by slicing empty objects (placeholders)
        //  walk backwards to prevent Array slice from changing future indexes
        for (let o = request.query.values.length - 1; o >= 0; o--) {
          for (let i = request.query.values[o].values.length - 1; i >= 0; i--) {
            if (Object.keys(request.query.values[o].values[i]).length === 0)
              request.query.values[o].values = [ ...request.query.values[o].values.slice(0, i), ...request.query.values[o].values.slice(i + 1, request.query.values[o].values.length) ]
          }
          if (request.query.values[o].values.length === 0)
            request.query.values = [ ...request.query.values.slice(0, o), ...request.query.values.slice(o + 1, request.query.values[o].values.length) ]
        }
        // append report id to api request(s)
        return { ...request, id: id.value }
      }
      // build search string from query_fields
      search.useString = searchString => {
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
      }
      search.columns = [
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
        })
      ]
      search.fields = query_fields.map(field => {
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
      search.reSearch()
    })
  }, { immediate: true })

   const description = computed(() => {
    const { description } = report.value
    return description
  })

  const hasCursor = computed(() => {
    const { has_cursor } = meta.value
    return has_cursor
  })

  const hasDateRange = computed(() => {
    const { has_date_range } = meta.value
    return has_date_range
  })

  return {
    report,
    meta,
    description,
    hasCursor,
    hasDateRange,

    // search
    useSearch,
    search,
    ...toRefs(search),
  }
}

// @vue/component
export default {
  name: 'TheReport',
  components,
  props,
  setup
}
</script>