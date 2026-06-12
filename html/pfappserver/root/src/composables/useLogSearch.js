import { computed, nextTick, ref, watch } from '@vue/composition-api'
import { useDebouncedWatchHandler } from '@/composables/useDebounce'

/**
 * In-results text search shared by the LiveLogs and HistoricalLogs views.
 * Kept cheap per keystroke (the views render up to 5000 live DOM rows): a
 * debounced `searchQuery` drives the recompute and a Set gives O(1) per-row
 * match membership. `matchText` is the exact text a row renders (not the raw
 * line), so the "x / N" counter and the <mark> highlight always agree.
 *
 * @param events       ref<Array>            the (filtered) events being shown
 * @param searchQuery  writable computed     store-backed query string
 * @param searchIsRegex writable computed    store-backed regex toggle
 * @param logRef       ref<HTMLElement>      the scroll container (for nav)
 * @param matchText    (event) => string     text a row renders == match source
 */
export const useLogSearch = ({ events, searchQuery, searchIsRegex, logRef, matchText }) => {
  const searchError = ref(false)
  const searchCurrentIdx = ref(0)

  const searchRegex = computed(() => {
    // Reset first so clearing the box (or a valid edit) also clears a stale
    // is-invalid state from a previously rejected pattern.
    searchError.value = false
    if (!searchQuery.value) return null
    try {
      const pattern = searchIsRegex.value
        ? searchQuery.value
        : searchQuery.value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
      return new RegExp(pattern, 'gi')
    } catch (e) {
      searchError.value = true
      return null
    }
  })

  // Indices in document order — navigation (next/prev) needs the order; the
  // Set derived from them gives O(1) per-row membership for rendering.
  const searchMatchIndices = computed(() => {
    const re = searchRegex.value
    if (!re || !events.value) return []
    return events.value.reduce((acc, event, idx) => {
      re.lastIndex = 0
      if (re.test(matchText(event) || '')) acc.push(idx)
      return acc
    }, [])
  })
  const searchMatchSet = computed(() => new Set(searchMatchIndices.value))
  const searchCurrentMatchIdx = computed(() => searchMatchIndices.value[searchCurrentIdx.value])

  const searchMatchCount = computed(() => searchMatchIndices.value.length)
  const searchCurrentDisplay = computed(() => searchMatchCount.value === 0 ? 0 : searchCurrentIdx.value + 1)

  watch(searchMatchIndices, () => {
    searchCurrentIdx.value = 0
  })

  // searchInput is the responsive UI value; debounced into the heavy
  // searchQuery (immediate:false so mount does not commit).
  const searchInput = ref(searchQuery.value)
  const _debounced = useDebouncedWatchHandler([searchInput], () => { // eslint-disable-line no-unused-vars
    searchQuery.value = searchInput.value
  }, { time: 300, immediate: false })
  // External resets (onSearchClear, store changes) must reflect back into the box.
  watch(searchQuery, v => {
    if (v !== searchInput.value) searchInput.value = v
  })

  const scrollToCurrentMatch = () => {
    nextTick(() => {
      if (!logRef.value) return
      const el = logRef.value.querySelector('.search-current')
      if (el) el.scrollIntoView({ block: 'center', behavior: 'smooth' })
    })
  }

  const onSearchNext = () => {
    if (searchMatchCount.value === 0) return
    searchCurrentIdx.value = (searchCurrentIdx.value + 1) % searchMatchCount.value
    scrollToCurrentMatch()
  }
  const onSearchPrev = () => {
    if (searchMatchCount.value === 0) return
    searchCurrentIdx.value = (searchCurrentIdx.value - 1 + searchMatchCount.value) % searchMatchCount.value
    scrollToCurrentMatch()
  }
  const onSearchClear = () => {
    searchInput.value = ''
    searchQuery.value = ''
    searchCurrentIdx.value = 0
  }

  // escapeHtml BEFORE highlight: the log line is untrusted content, only our
  // own <mark> wrapper may carry markup into v-html.
  const escapeHtml = (text) => String(text || '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')

  // Highlight only the rows that actually matched (Set lookup): non-matching
  // rows — the majority — skip the regex replace and just get escaped.
  const highlightEscaped = (text, idx) => {
    const escaped = escapeHtml(text)
    const re = searchRegex.value
    if (!re || !searchMatchSet.value.has(idx)) return escaped
    re.lastIndex = 0
    return escaped.replace(re, match => `<mark>${match}</mark>`)
  }

  const isSearchMatch = (idx) => searchMatchSet.value.has(idx)
  const isSearchCurrent = (idx) => idx === searchCurrentMatchIdx.value

  return {
    searchInput,
    searchError,
    searchMatchCount,
    searchCurrentDisplay,
    onSearchNext,
    onSearchPrev,
    onSearchClear,
    highlightEscaped,
    isSearchMatch,
    isSearchCurrent
  }
}
