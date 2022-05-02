<template>
  <base-search :use-search="useSearch">
    <template v-slot:header>
      <p class="py-0 col-form-label text-left text-nowrap" v-text="'Condition'"></p>
    </template>
    <template v-slot:footer>
      <b-row class="mt-3">
        <b-col cols="4">
          <p class="py-0 col-form-label text-left text-nowrap" v-text="'Group By'"></p>
          <base-input-chosen-one v-model="groupBy"
            :options="groupByOptions" />
        </b-col>
        <b-col cols="4">
          <p class="py-0 col-form-label text-left text-nowrap" v-text="'Order By'"></p>
          <base-input-chosen-one v-model="sortBy"
            :options="sortByOptions" />
        </b-col>
        <b-col cols="4">
          <p class="py-0 col-form-label text-left text-nowrap" v-text="'Sort'"></p>
          <base-input-chosen-one v-model="sortDesc"
            :options="sortDescOptions" />
        </b-col>
      </b-row>
    </template>
  </base-search>
</template>

<script>
import {
  BaseInputChosenOne,
  BaseSearch,
} from '@/components/new/'

const components = {
  BaseInputChosenOne,
  BaseSearch
}

const props = {}

import { ref, toRefs, watch } from '@vue/composition-api'
import i18n from '@/utils/locale'
import { useSearch } from '../_composables/useCollection'

const setup = (props, context) => {

  const search = useSearch()
  const {
    reSearch
  } = search
  const {
    items,
    visibleColumns,
    sortBy,
    sortDesc
  } = toRefs(search)

  const groupBy = ref('id')
  const groupByOptions = ref(
    search.columns
      .filter(column => column.sortable)
      .map(column => ({ text: i18n.t(column.label), value: column.key }))
  )

  const sortByOptions = ref(
    search.columns
      .filter(column => column.sortable)
      .map(column => ({ text: i18n.t(column.label), value: column.key }))
  )

  const sortDescOptions = ref([
    { text: i18n.t('Ascending'), value: false },
    { text: i18n.t('Descending'), value: true },
  ])

  watch([groupBy, sortBy, sortDesc], () => {
    search.requestInterceptor = request => {
//      request.scope = scope.value
      if (sortBy.value) {
        // rewrite current request
        request.query = { op: 'and', values: [
          { op: 'or', values: [
            { field: 'parent_id', op: 'equals', value: sortBy.value }
          ] }
        ] }
      }
      return request
    }
    reSearch()
  }, { immediate: true })

  return {
    groupBy,
    groupByOptions,
    sortByOptions,
    sortDescOptions,
    useSearch,

    ...toRefs(search),
  }
}

// @vue/component
export default {
  name: 'the-search',
  components,
  props,
  setup
}
</script>