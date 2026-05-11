<template>
  <span>
    <b-button :variant="variant" :size="size" :disabled="disabled || isLoading"
      @click="onStart">
      <icon name="file-export" class="mr-2" />
      <slot>{{ $t('Export all to CSV') }}</slot>
    </b-button>
    <b-modal v-model="show" size="md" centered :no-close-on-backdrop="isLoading"
      :no-close-on-esc="isLoading" :hide-header-close="isLoading"
      :title="$t('Export all to CSV')">
      <b-container fluid class="px-0">
        <p class="mb-2" v-if="isLoading">
          {{ $t('Fetching {fetched} of {total} rows…', { fetched: fetched, total: totalLabel }) }}
        </p>
        <p class="mb-2" v-else-if="errorMessage">
          <span class="text-danger">{{ errorMessage }}</span>
        </p>
        <p class="mb-2" v-else>
          {{ $t('Fetched {fetched} rows. Preparing download…', { fetched: fetched }) }}
        </p>
        <b-progress :max="100" height="8px">
          <b-progress-bar :value="percent" variant="success" :show-value="false" />
          <b-progress-bar :value="100 - percent" variant="light" :show-value="false" style="opacity: 0.2" />
        </b-progress>
      </b-container>
      <template #modal-footer>
        <b-button variant="secondary" @click="onCancel">
          {{ isLoading ? $t('Cancel') : $t('Close') }}
        </b-button>
      </template>
    </b-modal>
  </span>
</template>

<script>
const props = {
  useSearch: {
    type: Function,
    required: true
  },
  disabled: {
    type: Boolean
  },
  variant: {
    type: String,
    default: 'outline-primary'
  },
  size: {
    type: String,
    default: 'md'
  },
  pageLimit: {
    type: Number,
    default: 1000
  }
}

import { computed, ref } from '@vue/composition-api'
import { useTableColumnsItems } from '@/composables/useCsv'
import { useDownload } from '@/composables/useDownload'
import i18n from '@/utils/locale'

const setup = (props, context) => {

  const { useSearch, pageLimit } = props
  const search = useSearch()

  const { root: { $router, $store } = {} } = context

  const show = ref(false)
  const isLoading = ref(false)
  const cancelled = ref(false)
  const fetched = ref(0)
  const total = ref(0)
  const errorMessage = ref(null)

  const totalLabel = computed(() => total.value || '?')
  const percent = computed(() => {
    if (!total.value) return isLoading.value ? 5 : 0
    return Math.min(100, Math.round((fetched.value / total.value) * 100))
  })

  const reset = () => {
    fetched.value = 0
    total.value = 0
    errorMessage.value = null
    cancelled.value = false
  }

  const onCancel = () => {
    if (isLoading.value) {
      cancelled.value = true
    } else {
      show.value = false
    }
  }

  const fetchAll = async () => {
    const limit = +pageLimit || 1000
    const fields = search.useFields(search.columns)
    const fieldsParam = fields.join(',')
    const sortString = search.sortBy
      ? (search.sortDesc ? `${search.sortBy} DESC` : `${search.sortBy}`)
      : undefined
    const sortArray = sortString ? [sortString] : undefined

    const useSearchEndpoint = !!search.lastQuery && 'search' in search.api
    const cursors = []
    const accum = []

    let pageNum = 1
    while (!cancelled.value) {
      let cursor
      if (search.useCursor) {
        cursor = search.useCursor(cursors, pageNum, limit)
      } else {
        cursor = (pageNum - 1) * limit || undefined
      }

      let _response
      if (useSearchEndpoint) {
        const _body = {
          fields,
          query: search.lastQuery,
          sort: sortArray,
          limit,
          cursor
        }
        const body = search.requestInterceptor
          ? search.requestInterceptor(_body)
          : _body
        _response = await search.api.search(body)
      } else if ('list' in search.api) {
        const params = {
          fields: fieldsParam,
          sort: sortString,
          limit,
          cursor
        }
        _response = await search.api.list(params)
      } else {
        throw new Error(i18n.t('No list or search API available for this view.'))
      }

      const response = search.responseInterceptor
        ? search.responseInterceptor(_response)
        : _response
      const { items = [], nextCursor, total_count } = response || {}
      const pageItems = items || []
      accum.push(...pageItems)
      fetched.value = accum.length
      if (total_count)
        total.value = total_count
      else if (!total.value)
        total.value = accum.length + (pageItems.length === limit ? limit : 0)

      if (nextCursor !== undefined && nextCursor !== null) {
        cursors[pageNum] = nextCursor
      }

      if (pageItems.length < limit) break
      if (total_count && accum.length >= total_count) break

      pageNum++
    }
    return accum
  }

  const onStart = async () => {
    reset()
    show.value = true
    isLoading.value = true
    try {
      const items = await fetchAll()
      if (cancelled.value) {
        return
      }
      const visibleColumns = search.visibleColumns
      const csv = useTableColumnsItems(visibleColumns, items)
      const path = ($router && $router.currentRoute && $router.currentRoute.path) || ''
      const filename = `${path.slice(1).replace(/\//g, '-')}-${(new Date()).toISOString()}.csv`
      useDownload(filename, csv, 'text/csv')
      show.value = false
    } catch (e) {
      errorMessage.value = (e && e.message) || i18n.t('Export failed.')
      if ($store) {
        $store.dispatch('notification/danger', { message: errorMessage.value })
      }
    } finally {
      isLoading.value = false
    }
  }

  return {
    show,
    isLoading,
    fetched,
    total,
    totalLabel,
    percent,
    errorMessage,
    onStart,
    onCancel
  }
}

// @vue/component
export default {
  name: 'base-button-export-csv-all',
  inheritAttrs: false,
  props,
  setup
}
</script>
