import { computed, ref } from '@vue/composition-api'

export const useBootstrapTableSelected = (tableRef, itemsRef, key = 'id') => {
  const selected = ref([])
  const selectedItems = computed(() => {
    return selected.value.map(_key => {
      return itemsRef.value.find(item => item[key] === _key)
    })
  })
  const onRowSelected = value => {
    selected.value = value.map(({ [key]: _key }) => _key)
  }
  const onAllSelected = () => {
    if (selected.value.length === 0) // select all
      tableRef.value.selectAllRows()
    else // select none
      tableRef.value.clearSelected()
  }
  const onItemSelected = index => {
    const { [index]: { [key]: _key } = {} } = itemsRef.value
    if (selected.value.includes(_key))
      tableRef.value.unselectRow(index)
    else
      tableRef.value.selectRow(index)
  }

  return {
    selected,
    selectedItems,
    onRowSelected,
    onAllSelected,
    onItemSelected
  }
}
