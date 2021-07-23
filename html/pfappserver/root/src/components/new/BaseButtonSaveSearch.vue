<template>
  <b-button-group>
    <b-button variant="primary" @click="onSearch" :disabled="disabled">{{ $t('Search') }}</b-button>
    <b-dropdown :disabled="disabled"
      variant="primary" right>
      <template v-if="canSave">
        <b-dropdown-header>{{ $t('Saved Searches') }}</b-dropdown-header>
        <b-dropdown-item @click="showSaveSearchModal=true">
          <icon class="position-absolute mt-1" name="save" />
          <span class="ml-4">{{ $t('Save Search') }}</span>
        </b-dropdown-item>
        <template v-if="saved.length > 0">
          <b-dropdown-item-button v-for="search in saved" :key="search.id" @click="onLoad(search)">
            <span @click.stop="onDelete(search)">
              <icon class="position-absolute mt-1" name="trash-alt" />
            </span>
            <span class="ml-4">{{ search.id }}</span>
          </b-dropdown-item-button>
        </template>
        <b-dropdown-divider />
      </template>
      <b-dropdown-header>{{ $t('Import / Export Search') }}</b-dropdown-header>
      <b-dropdown-item @click="showExportJsonModal=true">
        <icon class="position-absolute mt-1" name="sign-out-alt" />
        <span class="ml-4">{{ $t('Export to JSON') }}</span>
      </b-dropdown-item>
      <b-dropdown-item @click="showImportJsonModal=true">
        <icon class="position-absolute mt-1" name="sign-in-alt" />
        <span class="ml-4">{{ $t('Import from JSON') }}</span>
      </b-dropdown-item>
    </b-dropdown>
    <b-modal v-model="showExportJsonModal" size="lg" centered id="exportJsonModal" :title="$t('Export to JSON')">
      <b-form-textarea ref="exportJsonTextarea" v-model="jsonValue" :rows="3" :max-rows="3" readonly/>
      <template v-slot:modal-footer>
        <b-button variant="secondary" class="mr-1" @click="showExportJsonModal=false">{{ $t('Cancel') }}</b-button>
        <b-button variant="primary" @click="copyJsonTextarea">{{ $t('Copy to Clipboard') }}</b-button>
      </template>
    </b-modal>
    <b-modal v-model="showImportJsonModal" size="lg" centered id="importJsonModal" :title="$t('Import from JSON')" @shown="focusImportJsonTextarea">
      <b-card v-if="importJsonError" class="mb-3" bg-variant="danger" text-variant="white"><icon name="exclamation-triangle" class="mr-1"></icon>{{ importJsonError }}</b-card>
      <b-form-textarea ref="importJsonTextarea" v-model="importJsonString" :rows="3" :max-rows="3" :placeholder="$t('Enter JSON')"></b-form-textarea>
      <template v-slot:modal-footer>
        <b-button variant="secondary" class="mr-1" @click="showImportJsonModal=false">{{ $t('Cancel') }}</b-button>
        <b-button variant="primary" @click="importJsonTextarea">{{ $t('Import JSON') }}</b-button>
      </template>
    </b-modal>
    <b-modal v-model="showSaveSearchModal" size="sm" centered id="saveSearchModal" :title="$t('Save Search')" @shown="focusSaveSearchInput">
      <b-form-input ref="saveSearchInput" v-model="saveSearchId" type="text"
        :placeholder="$t('Enter a unique name')" @keyup="keyUpSaveSearchInput"/>
      <template v-slot:modal-footer>
        <b-button variant="secondary" class="mr-1" @click="showSaveSearchModal=false">{{ $t('Cancel') }}</b-button>
        <b-button variant="primary" @click="onSave">{{ $t('Save') }}</b-button>
      </template>
    </b-modal>
  </b-button-group>
</template>

<script>
const props = {
  saveSearchNamespace: {
    type: String
  },
  useSearch: {
    type: Function
  },
  value: {
    type: [String, Array, Object]
  },
  disabled: {
    type: Boolean
  },
  id: {
    type: String
  }
}

import { computed, onMounted, ref, toRefs, watch } from '@vue/composition-api'
import i18n from '@/utils/locale'

const setup = (props, context) => {

  const {
    saveSearchNamespace,
    value,
    id
  } = toRefs(props)

  const {
    useSearch
  } = props
  const search = useSearch()
  const {
    setUp
  } = search
  const {
    columns,
    page,
    limit,
    sortBy,
    sortDesc
  } = toRefs(search)

  const { emit, refs, root: { $store } = {} } = context

  const onSearch = () => emit('search')

  const jsonValue = ref(null)
  watch(value, () => {
    jsonValue.value = JSON.stringify(value.value)
  }, { deep: true, immediate: true })

  onMounted(() => $store.dispatch('preferences/get', saveSearchNamespace.value))
  const canSave = computed(() => saveSearchNamespace.value)
  const saved = computed(() => {
    const { values = {} } = $store.state.preferences.cache[saveSearchNamespace.value] || {}
    return Object.keys(values).map(id => ({ id, ...values[id] }))
  })

  const showExportJsonModal = ref(false)
  const showImportJsonModal = ref(false)
  const importJsonString = ref(null)
  const importJsonError = ref(null)
  const showSaveSearchModal = ref(false)

  const saveSearchId = ref(null)
  watch(id, () => { // default id
    saveSearchId.value = id.value
  }, { immediate: true })

  const copyJsonTextarea = () => {
    if (document.queryCommandSupported('copy')) {
      refs.exportJsonTextarea.$el.select()
      document.execCommand('copy')
      showExportJsonModal.value = false
      $store.dispatch('notification/info', { message: i18n.t('Search copied to clipboard') })
    }
  }

  const importJsonTextarea = () => {
    importJsonError.value = ''
    try {
      const json = JSON.parse(importJsonString.value)
      emit('input', json)
      importJsonString.value = null
      showImportJsonModal.value = false
      $store.dispatch('notification/info', { message: i18n.t('Search imported') })
    } catch (e) {
      if (e instanceof SyntaxError)
        importJsonError.value = i18n.t('Invalid JSON') + ': ' + e.message
      else
        importJsonError.value = i18n.t('Unhandled error') + ': ' + e.message
    }
  }

  const focusImportJsonTextarea = () => {
    refs.importJsonTextarea.focus()
  }

  const focusSaveSearchInput = () => {
    refs.saveSearchInput.focus()
  }

  const keyUpSaveSearchInput = event => {
    switch (event.keyCode) {
      case 13: // [ENTER] submits
        if (saveSearchId.value.length > 0)
          onSave()
        break
    }
  }

  const onSave = () => {
    const { values = {} } = $store.state.preferences.cache[saveSearchNamespace.value] || {}
    values[saveSearchId.value] = {
      columns: columns.value.filter(c => c.visible).map(c => c.key),
      page: page.value,
      limit: limit.value,
      sortBy: sortBy.value,
      sortDesc: sortDesc.value,
      query: value.value
    }
    $store.dispatch('preferences/set', {
      id: saveSearchNamespace.value,
      value: { values }
    }).then(() => {
      showSaveSearchModal.value = false
    })
  }

  const onDelete = search => {
    const { values = {} } = $store.state.preferences.cache[saveSearchNamespace.value] || {}
    delete values[search.id]
    $store.dispatch('preferences/set', {
      id: saveSearchNamespace.value,
      value: { values }
    })
  }

  const onLoad = search => {
    setUp(search)
    emit('input', search.query)
    emit('search')
  }

  return {
    onSearch,
    jsonValue,
    canSave,
    saved,

    showExportJsonModal,
    showImportJsonModal,
    importJsonString,
    importJsonError,
    showSaveSearchModal,
    saveSearchId,

    copyJsonTextarea,
    importJsonTextarea,
    focusImportJsonTextarea,
    focusSaveSearchInput,
    keyUpSaveSearchInput,
    onSave,
    onDelete,
    onLoad,
  }
}

// @vue/component
export default {
  name: 'base-button-save-search',
  inheritAttrs: false,
  props,
  setup
}
</script>
