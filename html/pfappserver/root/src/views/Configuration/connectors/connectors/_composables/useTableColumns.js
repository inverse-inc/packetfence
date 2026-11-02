import { computed } from '@vue/composition-api'
import usePreference from '@/composables/usePreference'
import i18n from '@/utils/locale'

// Column picker state for a client-side b-table (same contract as the search
// tables: BaseSearchInputColumns :value="columns" @input="setColumns").
// Definitions use untranslated labels (// i18n defer); the visible keys are
// kept as a per-user preference.
export const useTableColumns = (preferenceId, definitions) => {
  const defaults = definitions.filter(column => column.visible).map(column => column.key)
  const visibleKeys = usePreference(preferenceId, 'columns', defaults)
  const columns = computed(() => definitions.map(column => ({
    ...column,
    visible: !!column.locked || visibleKeys.value.includes(column.key)
  })))
  const visibleColumns = computed(() => columns.value
    .filter(column => column.visible)
    .map(column => ({ ...column, label: column.label && i18n.t(column.label) }))
  )
  const setColumns = newColumns => {
    visibleKeys.value = newColumns.filter(column => column.visible && !column.locked).map(column => column.key)
  }
  return {
    columns,
    visibleColumns,
    setColumns
  }
}
