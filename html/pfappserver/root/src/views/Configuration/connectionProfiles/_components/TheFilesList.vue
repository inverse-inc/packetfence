<template>
  <div>
    <input-toggle
      v-model="hideDefaultFiles"
      :options="[
        { value: false, label: $i18n.t('Show all files') },
        { value: true, label: $i18n.t('Show modified files only'), color: 'var(--primary)' }
      ]"
      label-class="d-none"
      label-right
    />
    <b-table :items="tableItems" :fields="tableFields" :sort-by="sortBy" :sort-desc="sortDesc"
      class="the-files-list"
      small hover responsive striped show-empty no-local-sorting no-select-on-click borderless
      @sort-changed="onSortChanged($event)"
      @row-clicked="onRowClicked($event)"
    >
      <template v-slot:cell(name)="{ item }">
        <div v-if="item.type === 'dir'"
          class="d-flex align-items-center"
          variant="link"
          :disabled="false"
        >
          <icon v-for="(name, n) in item.icons" :key="n"
            :name="name" class="nav-icon" />

          <icon v-if="item.expand"
            name="regular/folder-open"/>
          <icon v-else
            name="regular/folder"/> {{ item.name }}
        </div>
        <div v-else
          class="d-flex align-items-center"
          variant="link"
          :class="{ 'text-primary': !item.not_revertible || !item.not_deletable }"
        >
          <icon v-for="(name, n) in item.icons" :key="n"
            :name="name" class="nav-icon" />

          <icon :name="(item.isImage) ? 'file-image' : 'file'" />

          <inline-name v-if="!item.not_revertible || !item.not_deletable"
            :key="`${item.path}/${item.name}`"
            :id="id" :item="item" :entries="entries" />
          <span v-else
            >{{ item.name }}</span>
        </div>
      </template>
      <template v-slot:cell(buttons)="{ item }">
        <div v-if="item.type === 'file'"
          class="text-right text-nowrap">

          <base-button-confirm v-if="!item.not_deletable"
            size="sm" variant="outline-danger" class="my-1 mr-1"
            :disabled="isLoading"
            :confirm="$t('Delete?')"
            reverse
            @click="onDelete(item)"
          >{{ $t('Delete') }}</base-button-confirm>

          <base-button-confirm v-else-if="!item.not_revertible"
            size="sm" variant="outline-danger" class="my-1 mr-1"
            :disabled="isLoading"
            :confirm="$t('Revert?')"
            reverse
            @click="onDelete(item)"
          >{{ $t('Revert') }}</base-button-confirm>

          <b-button v-if="previewUrl"
            size="sm" variant="outline-secondary" class="my-1"
            :href="previewUrl(item)" target="_blank"
          >{{ $t('Preview') }} <icon class="ml-1" name="external-link-alt"></icon></b-button>
        </div>
        <div v-else-if="item.type === 'dir'"
          class="text-right text-nowrap">

          <b-dropdown size="sm" variant="outline-primary" class="my-1" right>
            <template #button-content>
              <icon name="plus-circle" />
            </template>
            <b-dropdown-header>{{ `${item.path}/${item.name}`.replace('//', '/') }}</b-dropdown-header>
            <b-dropdown-divider />
            <b-dropdown-item @click="onToggleDirectory(item)">{{ $i18n.t('Create New Sub Directory') }}</b-dropdown-item>
            <b-dropdown-item @click="onToggleEdit(item)">{{ $i18n.t('Create New File') }}</b-dropdown-item>
            <b-dropdown-item @click="onToggleUpload(item)">
              <base-button-upload
                @files="onUploadFiles(item, $event)"
                :accept="acceptMimes"
                multiple
              >{{ $i18n.t('Upload File(s)') }}</base-button-upload>
            </b-dropdown-item>
          </b-dropdown>

        </div>
      </template>
    </b-table>

    <modal-directory
      v-model="isShowDirectoryModal"
      :entries="entries"
      :id="id"
      :path="lastPath"
      @create="onCreateDirectory($event)"
      @hidden="onToggleDirectory"
    />

    <modal-edit
      v-model="isShowEditModal"
      :entries="entries"
      :id="id"
      :path="lastPath"
      @create="onCreateFile($event)"
      @update="onUpdateFile($event)"
      @delete="onDeleteFile($event)"
      @hidden="onToggleEdit"
    />

    <modal-view
      v-model="isShowViewModal"
      :entries="entries"
      :id="id"
      :path="lastPath"
      @delete="onDeleteFile($event)"
      @hidden="onToggleView"
    />

  </div>
</template>
<script>
import {
  BaseButtonConfirm,
  BaseButtonUpload,
  BaseFormGroupToggle
} from '@/components/new/'
import {
  InlineName,
  ModalDirectory,
  ModalEdit,
  ModalView,
} from './'

const components = {
  BaseButtonConfirm,
  BaseButtonUpload,
  InlineName,
  InputToggle: BaseFormGroupToggle,
  ModalDirectory,
  ModalEdit,
  ModalView,
}

const props = {
  id: {
    type: String
  }
}

import { pfFormatters } from '@/globals/pfFormatters'

const tableFields = [
  {
    key: 'name',
    label: 'Name', // i18n defer
    class: 'w-50 text-nowrap',
    required: true,
    sortable: true
  },
  {
    key: 'size',
    label: 'Size', // i18n defer
    formatter: pfFormatters.fileSize,
    tdClass: 'text-right text-nowrap',
    thClass: 'text-right text-nowrap',
    sortable: true
  },
  {
    key: 'mtime',
    label: 'Last modification', // i18n defer
    formatter: value => { // suppress 'Never'
      return (value) ? pfFormatters.shortDateTime(value) : ''
    },
    tdClass: 'text-right text-nowrap',
    thClass: 'text-right text-nowrap',
    sortable: true
  },
  {
    key: 'buttons',
    label: '',
    locked: true
  }
]

import { computed, ref, toRefs, watch } from '@vue/composition-api'
import i18n from '@/utils/locale'
import { reAscii } from '@/utils/regex'
import { acceptMimes } from '../config'
import { fileNotExists } from '../schema'

const setup = (props, context) => {

  const {
    id
  } = toRefs(props)

  const { root: { $store } = {} } = context

  const sortBy = ref(undefined)
  const sortDesc = ref(false)

  const expandPaths = ref(['/'])
  const expandPath = (path) => {
    expandPaths.value = [ ...expandPaths.value, path ]
  }
  const collapsePath = (path) => {
    if (path === '/') return
    expandPaths.value = expandPaths.value.filter(_path => {
      if (_path.indexOf(path) !== 0)
        return _path
    })
  }

  const tableItems = ref([])
  const isLoading = computed(() => $store.getters['$_connection_profiles/isLoadingFiles'])
  //const entries = ref([])
  const entries = computed(() => {
    const { [id.value]: { entries = [] } = {} } = $store.state.$_connection_profiles.files.cache
    return [{
      name: '/',
      type: 'dir',
      entries: JSON.parse(JSON.stringify(entries))
    }]
  })

  const _getFiles = () => {
    let sort = ['type']
    if (sortBy.value) {
      let _sortBy = sortDesc.value ? `${sortBy.value} DESC` : sortBy.value
      sort.push(_sortBy)
    }
    else
      sort.push('name')
    $store.dispatch('$_connection_profiles/files', { id: id.value, sort })
  }

  watch([sortBy, sortDesc], () => _getFiles(), { immediate: true })

  const hideDefaultFiles = ref(false)
  watch([entries, expandPaths, hideDefaultFiles], () => {
    if (hideDefaultFiles.value) {
      // Only show modified files and automatically expand all applicable directories
      const visibleFilter = e => (e.type == 'dir' || e.not_revertible === false || e.not_deletable === false)
      const reduceEntries = (entries, depth = 0, path = '', _icons = []) => {
        return entries.reduce((reduced, entry, e) => {
          const last = (e === entries.length - 1)
          let icons = _icons
          if (depth > 0)
            icons = [ ..._icons, (last) ? 'tree-last' : 'tree-node' ]
          let { entries: childEntries = [], ...rest } = entry || {}
          const { type, name } = rest || {}
          const fullPath = `${path}/${name}`.replace('//', '/')
          switch(type) {
            case 'dir':
              childEntries = childEntries.filter(visibleFilter)
              if (childEntries.length) {
                let dirEntries
                if (depth > 0)
                  dirEntries = reduceEntries(childEntries, depth + 1, fullPath, [ ..._icons, (last) ? 'tree-skip' : 'tree-pass' ])
                else
                  dirEntries = reduceEntries(childEntries, depth + 1, fullPath, _icons)
                if (dirEntries.length) {
                  reduced.push({ ...rest, path, expand: true, icons })
                  reduced.push(...dirEntries);
                }
              }
              break
            case 'file':
              reduced.push({ ...rest, path, icons,
                isImage: (['gif', 'jpg', 'jpeg', 'png'].includes(name.split('.').reverse()[0].toLowerCase()))
              })
              break
          }
          return reduced
        }, [])
      }
      tableItems.value = reduceEntries(entries.value.filter(visibleFilter))
    }
    else {
      const reduceEntries = (entries, depth = 0, path = '', _icons = []) => {
        return entries.reduce((reduced, entry, e) => {
          const last = (e === entries.length - 1)
          let icons = _icons
          if (depth > 0)
            icons = [ ..._icons, (last) ? 'tree-last' : 'tree-node' ]
          const { entries: childEntries = [], ...rest } = entry || {}
          const { type, name } = rest || {}
          const fullPath = `${path}/${name}`.replace('//', '/')
          switch(type) {
            case 'dir':
              if (expandPaths.value.includes(fullPath)) {
                reduced.push({ ...rest, path, expand: true, icons })
                if (depth > 0)
                  reduced.push(...reduceEntries(childEntries, depth + 1, fullPath, [ ..._icons, (last) ? 'tree-skip' : 'tree-pass' ]))
                else
                  reduced.push(...reduceEntries(childEntries, depth + 1, fullPath, _icons))
              }
              else
                reduced.push({ ...rest, path, expand: false, icons })
              break
            case 'file':
              reduced.push({ ...rest, path, icons,
                isImage: (['gif', 'jpg', 'jpeg', 'png'].includes(name.split('.').reverse()[0].toLowerCase()))
              })
              break
          }
          return reduced
        }, [])
      }
      tableItems.value = reduceEntries(entries.value)
    }
  }, { deep: true })

  const onSortChanged = (params) => {
    sortBy.value = params.sortBy
    sortDesc.value = params.sortDesc
  }

  const onRowClicked = (row) => {
    const { path, name, type } = row || {}
    if (type === 'dir') {
      const fullPath = `${path}/${name}`.replace('//', '/')
      if (expandPaths.value.includes(fullPath))
        collapsePath(fullPath)
      else
        expandPath(fullPath)
    }
    else if (type === 'file') {
      const extension = name.split('.').reverse()[0]
      switch (extension.toLowerCase()) {
        case 'gif':
        case 'jpg':
        case 'jpeg':
        case 'png':
          onToggleView(row)
          break
        default:
          onToggleEdit(row)
      }
    }
  }

  const onDelete = (item) => {
    const { path, name } = item
    $store.dispatch('$_connection_profiles/deleteFile', { id: id.value, filename: `${path}/${name}`.replace('//', '/') })
  }

  const previewUrl = (item) => {
    let path = ['/config/profile', id.value, 'preview']
    if (item.path)
      path.push(...item.path.split('/').filter(u => u))
    path.push(item.name)
    return path.join('/')
  }

  const lastPath = ref(undefined)
  const isShowDirectoryModal = ref(false)
  const onToggleDirectory = (item) => {
    const { path = '', name = '' } = item || {}
    lastPath.value = `${path}/${name}`.replace('//', '/')
    isShowDirectoryModal.value = !isShowDirectoryModal.value
  }

  const isShowEditModal = ref(false)
  const onToggleEdit = (item) => {
    const { path = '', name = '' } = item || {}
    lastPath.value = `${path}/${name}`.replace('//', '/')
    isShowEditModal.value = !isShowEditModal.value
  }

  const isShowViewModal = ref(false)
  const onToggleView = (item) => {
    const { path = '', name = '' } = item || {}
    lastPath.value = `${path}/${name}`.replace('//', '/')
    isShowViewModal.value = !isShowViewModal.value
  }

  const isShowUploadModal = ref(false)
  const onToggleUpload = (item) => {
    const { path = '', name = '' } = item || {}
    lastPath.value = `${path}/${name}`.replace('//', '/')
    isShowUploadModal.value = !isShowUploadModal.value
  }

  const onCreateDirectory = (name) => {
    let _entries = entries.value
    let parts = ['/', ...lastPath.value.split('/').filter(p => p)]
    // traverse tree using path parts
    while (parts.length > 0) {
      for (let e = 0; e < _entries.length; e++) {
        const { name, entries: childEntries = [] } = _entries[e]
        if (name === parts[0]) {
          _entries = childEntries
          break
        }
      }
      parts = parts.slice(1)
    }
    _entries.push({ type: 'dir', name, size: 0, mtime: 0, entries: [] })
    expandPath(lastPath.value)
  }

  const onCreateFile = (path) => {
    lastPath.value = path
    expandPath(lastPath.value)
    _getFiles()
  }

  const onUpdateFile = () => _getFiles()

  const onDeleteFile = () => {
    isShowEditModal.value = false
    isShowViewModal.value = false
    _getFiles()
  }

  const onUploadFiles = (item, files) => {
    const { path, name } = item
    const pathname = `${path}/${name}`.replace('//', '/')
    files.forEach(file => {
      const filename = file.name.trim()
      if(!reAscii(filename)) {
        return $store.dispatch('notification/danger', {
          icon: 'exclamation-triangle',
          url: filename,
          message: i18n.t('Upload skipped. {filename} contains non-ASCII characters and is not a valid filename.', { filename: `<code>${filename}</code>` })
        })
      }
      const exists = !fileNotExists(entries.value, pathname, filename)
      let method = 'createFile'
      let message = i18n.t('{file} uploaded.', { file: `<code>${pathname}/${filename}</code>` })
      if (exists) {
        method = 'updateFile'
        message = i18n.t('{file} replaced.', { file: `<code>${pathname}/${filename}</code>` })
      }
      $store.dispatch(`${file.storeName}/readAsDataURL`).then(content => {
        $store.dispatch(`$_connection_profiles/${method}`, {
          id: id.value,
          filename: `${pathname}/${filename}`.replace('//', '/'),
          content,
          quiet: true
        }).then(() => {
          $store.dispatch('notification/info', { url: filename, message })
        }).catch(error => {
          const { response: { data: { message = '' } = {} } = {} } = error
          $store.dispatch('notification/danger', { icon: 'exclamation-triangle', url: filename, message })
          throw error
        }).finally(_getFiles)
      })
    })
  }

  return {
    sortBy,
    sortDesc,
    entries,
    expandPaths,
    tableFields,
    tableItems,
    isLoading,
    onDelete,
    onSortChanged,
    onRowClicked,
    previewUrl,

    isShowDirectoryModal,
    onCreateDirectory,
    onToggleDirectory,

    isShowEditModal,
    onCreateFile,
    onUpdateFile,
    onDeleteFile,
    onToggleEdit,

    isShowViewModal,
    onToggleView,

    isShowUploadModal,
    onToggleUpload,

    lastPath,
    hideDefaultFiles,

    onUploadFiles,
    acceptMimes,
  }
}

// @vue/component
export default {
  name: 'the-files-list',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
<style lang="scss">
$table-cell-height: 2.5 * $spacer !default;

.the-files-list {
  thead[role="rowgroup"] {
    border-bottom: 1px solid #dee2e6 !important;
  }
  tr[role="row"],
  tr[role="row"] > th[role="columnheader"] {
    cursor: pointer;
    outline-width: 0;
    td[role="cell"] {
      height: $table-cell-height;
      padding: 0 0.3rem;
      word-wrap: nowrap;
      div[variant="link"] {
        line-height: 1em;
      }
    }
    td[aria-colindex="1"] {
      svg.fa-icon:not(.nav-icon) {
        min-width: $table-cell-height;
        height: auto;
        max-height: $table-cell-height/2;
        margin: 0.25rem 0;
      }
      svg.nav-icon {
        height: $table-cell-height;
        color: $gray-500;
      }
    }
  }
}
</style>
