<template>
  <b-modal v-model="show"
    @shown="onShown"
    @hidden="onHidden"
    size="xl" class="modal-full" body-class="p-0"
  >
    <template v-slot:modal-title>
      <span v-if="isNew"
        >{{ $i18n.t('Create New File in') }} <code>{{ path }}</code></span>
      <span v-else
        >{{ $i18n.t('Edit File') }} <code>{{ path }}</code></span>
    </template>
    <template v-slot:default>
      <b-form @submit.prevent="onSave" ref="formRef" v-if="isNew">
        <base-form
          :form="form"
          :schema="schema"
          :isLoading="isLoading"
        >
          <form-group-name namespace="name"
            :column-label="$i18n.t('New Filename')"
            placeholder="filename.html"
          />
        </base-form>
      </b-form>
      <b-form-row class="align-items-center my-1 px-3">
        <b-col cols="auto" class="mr-auto">
          <form-group-toggle
            v-model="isEditorLineNumbers"
            :options="[
              { value: false, label: $i18n.t('Hide line numbers') },
              { value: true, label: $i18n.t('Show line numbers'), color: 'var(--primary)' }
            ]"
            label-class="d-none"
            label-right
          />
        </b-col>
        <b-col cols="auto">
          <b-dropdown :disabled="isLoading"
            size="sm" variant="outline-secondary" right>
            <template v-slot:button-content>
              <icon name="code" :title="$t('Insert variable')"></icon> {{ $t('Insert variable') }}
            </template>
            <b-dropdown-item v-for="variable in editorVariables" :key="variable" @click="onEditorVariable(variable)">
              {{ variable }}
            </b-dropdown-item>
          </b-dropdown>
          <b-button v-if="previewUrl"
            size="sm" variant="outline-secondary" class="ml-1"
            :href="previewUrl" target="_blank"
          >{{ $t('Preview') }} <icon class="ml-1" name="external-link-alt"></icon></b-button>
        </b-col>
      </b-form-row>
      <div class="ace-container flex-grow-1 px-3" ref="editorRef">
        <ace-editor v-model="editorContent" theme="cobalt" lang="html" :height="editorHeight" @init="onEditorInit"></ace-editor>
      </div>
    </template>
    <template v-slot:modal-footer>
      <b-button v-if="isNew"
        class="mr-1" variant="primary" :disabled="!isValid" @click="onSave">{{ $t('Create') }}</b-button>
      <b-button v-else
        class="mr-1" variant="primary" :disabled="!isValid" @click="onSave">{{ $t('Save') }}</b-button>
      <button-delete v-if="isDeletable"
        variant="danger" class="mr-1"
        :disabled="isLoading"
        :confirm="$t('Delete file?')"
        reverse
        @click="onDelete"
      >{{ $t('Delete') }}</button-delete>
      <button-revert v-else-if="isRevertible"
        variant="danger" class="mr-1"
        :disabled="isLoading"
        :confirm="$t('Dicard changes?')"
        reverse
        @click="onDelete"
      >{{ $t('Revert') }}</button-revert>
      <b-button v-if="isNew"
        class="mr-1" variant="secondary" @click="onHide">{{ $t('Cancel') }}</b-button>
      <b-button v-else
        class="mr-1" variant="secondary" @click="onHide">{{ $t('Close') }}</b-button>
    </template>
  </b-modal>
</template>
<script>
import aceEditor from 'vue2-ace-editor'
import {
  BaseButtonConfirm,
  BaseForm,
  BaseFormGroupInput,
  BaseFormGroupToggle
} from '@/components/new/'

const components = {
  aceEditor,
  BaseForm,
  ButtonDelete: BaseButtonConfirm,
  ButtonRevert: BaseButtonConfirm,
  FormGroupName: BaseFormGroupInput,
  FormGroupToggle: BaseFormGroupToggle
}

const props = {
  entries: {
    type: Array
  },
  id: {
    type: String
  },
  path: {
    type: String,
    default: ''
  },
  value: { // v-model: show/hide
    type: Boolean
  }
}

import { computed, customRef, nextTick, onMounted, onBeforeUnmount, ref, toRefs, watch } from '@vue/composition-api'
import { createDebouncer } from 'promised-debounce'
import { useDebouncedWatchHandler } from '@/composables/useDebounce'
import useEventJail from '@/composables/useEventJail'
import i18n from '@/utils/locale'
import { acceptTextMimes } from '../config'
import { yup } from '../schema'

const defaults = () => ({
  name: undefined
})

const setup = (props, context) => {

  const { root: { $store } = {}, emit } = context

  const {
    entries,
    id,
    path,
    value,
  } = toRefs(props)

  const schema = computed(() => yup.object({
    name: yup.string()
      .required(i18n.t('File name required.'))
      .isFilenameWithContentType(acceptTextMimes)
      .fileNotExists(entries.value, path.value, i18n.t('File exists.'))
  }))

  const form = ref(defaults())
  const formRef = ref(null)
  useEventJail(formRef)
  const isLoading = computed(() => $store.getters['$_connection_profiles/isLoadingFiles'])

  const _isNew = (entries, path) => {
    // traverse tree using path parts
    let lastType
    let parts = ['/', ...path.split('/').filter(p => p)]
    while (parts.length > 0) {
      for (let e = 0; e < entries.length; e++) {
        const { type, name, entries: childEntries = [] } = entries[e]
        lastType = type
        if (name === parts[0]) {
          entries = childEntries
          break
        }
      }
      parts = parts.slice(1)
    }
    return lastType === 'dir' || entries.length > 0
  }
  const isNew = computed(() => _isNew(entries.value, path.value))

  const previewUrl = computed(() => {
    if (isNew.value)
      return false
    let url = ['/config/profile', id.value, 'preview']
    if (path.value)
      url.push(...path.value.split('/').filter(u => u))
    return url.join('/')
  })

  const isDeletable = ref(false)
  const isRevertible = ref(false)
  watch([path, entries], () => {
    const isNew = _isNew(entries.value, path.value)
    if (isNew) {
      editorContent.value = ''
      isDeletable.value = false
      isRevertible.value = false
    }
    else {
      $store.dispatch('$_connection_profiles/getFile', { id: id.value, filename: path.value }).then(response => {
        const { content: { message }, meta: { not_deletable, not_revertible } = {} } = response
        editorContent.value = decodeURIComponent(escape(atob(message)))
        isDeletable.value = !not_deletable
        isRevertible.value = !not_revertible
      })
    }
  }, { deep: true })

  const isValid = useDebouncedWatchHandler([form, path, entries], () => (!formRef.value || formRef.value.querySelectorAll('.is-invalid').length === 0))

  const onDelete = () => {
    $store.dispatch('$_connection_profiles/deleteFile', { id: id.value, filename: path.value }).then(() => {
      emit('delete', path.value)
    })
  }

  const onSave = () => {
    const action = (isDeletable.value || isRevertible.value) ? 'update' : 'create'
    let params = {
      id: id.value,
      filename: path.value.split('/').filter(u => u).join('/'),
      content: btoa(unescape(encodeURIComponent(editorContent.value)))
    }
    if (isNew.value)
      params.filename += `/${form.value.name}`
    return $store.dispatch(`$_connection_profiles/${action}File`, params).then(() => {
      emit(action, params.filename)
    })
  }

  const show = customRef((track, trigger) => ({ // use v-model
    get() {
      track()
      return value.value
    },
    set(newValue) {
      emit('input', newValue)
      trigger()
    }
  }))

  const resetForm = () => {
    form.value = defaults()
  }

  const onShown = () => {
    resetForm() // reset form when shown
    onResizeEditor()
  }
  const onHidden = () => resetForm() // reset form when hidden

  const onHide = () => {
    show.value = false
  }

  const editor = ref(undefined)
  const editorHeight = ref('0px')
  const editorRef = ref(null)
  const editorContent = ref('')
  const editorVariables = [ 'logo', 'username', 'user_agent', 'device_class', 'last_switch', 'last_port', 'last_vlan', 'last_connection_type', 'last_ssid' ]
  const isEditorLineNumbers = ref(true)

  const onEditorInit = (instance) => {
    // Load ACE editor extensions
    require('brace/ext/language_tools')
    require('brace/ext/searchbox')
    require('brace/mode/html')
    require('brace/theme/cobalt')
    editor.value = instance
    editor.value.setAutoScrollEditorIntoView(true)
    editor.value.renderer.setShowPrintMargin(false)
    onResizeEditor()

    watch(isEditorLineNumbers, () => {
      editor.value.renderer.setShowGutter(isEditorLineNumbers.value)
    }, { immediate: true })

    watch(isLoading, () => {
      editor.value.setReadOnly(isLoading.value)
    }, { immediate: true })
  }

  const onResizeDecouncer = createDebouncer()
  const onResizeEditor = () => {
    onResizeDecouncer({
      handler: () => {
        nextTick(() => {
          const element = editorRef.value
          if (element && window.getComputedStyle) {
            const container = element.parentNode
            container.style.overflow = 'hidden'
            const style = getComputedStyle(container)
            delete container.style.overflow
            // [total container height] - [element top offset] - [padding bottom]
            const height = container.clientHeight - element.offsetTop - parseFloat(style.paddingTop)
            const minHeight = Math.max(height, 200) // min 200
            editorHeight.value = `${minHeight}px`
            editor.value.resize()
          }
          else
            editorHeight.value = '200px'
        })
      },
      time: 300
    })
  }
  watch([isNew, isValid], onResizeEditor)
  onMounted(() => window.addEventListener('resize', onResizeEditor))
  onBeforeUnmount(() => window.removeEventListener('resize', onResizeEditor))

  const onEditorVariable = (variable) => {
    editor.value.insert(`[% ${variable} %]`)
    editor.value.focus()
  }

  return {
    form,
    formRef,
    schema,
    isLoading,
    isDeletable,
    isRevertible,
    isNew,
    isValid,
    onDelete,
    onSave,
    previewUrl,

    // modal
    show,
    onHide,
    onShown,
    onHidden,

    // ACE editor
    editorHeight,
    editorRef,
    editorContent,
    editorVariables,
    isEditorLineNumbers,
    onEditorInit,
    onEditorVariable
  }
}

export default {
  name: 'modal-edit',
  components,
  props,
  setup
}
</script>
<style lang="scss" scoped>
::v-deep {
  .modal-dialog {
    & > .modal-content {
      /* take max height */
      height: calc(100vh - (2 * 1.75rem)); /* 2 x $modal-dialog-margin-y-sm-up */
    }
  }
}
</style>
