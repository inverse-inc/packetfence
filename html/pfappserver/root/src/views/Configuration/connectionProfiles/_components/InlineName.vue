<template>
  <div @click.stop class="d-flex flex-grow-1">
    <template v-if="!rename">
      <span style="cursor: text;" @click.stop="onShow"
        v-b-tooltip.hover.top.d300 :title="$i18n.t('Click to rename')"
      >{{ item.name }}</span>
    </template>
    <template v-else>
      <b-form @submit.prevent="onRename" ref="formRef"
        class="d-flex w-100">
        <base-form
          class="p-0 my-1 w-100"
          :form="form"
          :schema="schema"
          :isLoading="isLoading || isRenaming"
        >
          <input-name namespace="name" ref="inputRef"
            class="w-100" :placeholder="item.name"
            @click.stop.prevent
          />
        </base-form>
        <b-button :disabled="isLoading || isRenaming || !canRename"
          size="sm" variant="primary" class="ml-1 my-1 py-0" @click="onRename">
            <template v-if="!isRenaming"
              >{{ $i18n.t('Rename') }}</template>
            <icon v-else
              name="circle-notch" spin />
        </b-button>
        <b-button :disabled="isLoading || isRenaming"
          size="sm" variant="danger" class="ml-1 my-1" @click.stop="onCancel">{{ $i18n.t('Cancel') }}</b-button>
      </b-form>
    </template>
  </div>
</template>
<script>
import {
  BaseForm,
  BaseInput,
} from '@/components/new/'

const components = {
  BaseForm,
  InputName: BaseInput,
}

const props = {
  id: {
    type: String
  },
  item: {
    type: Object
  },
  entries: {
    type: Array
  },
}

import { computed, nextTick, ref, toRefs, watch } from '@vue/composition-api'
import { useDebouncedWatchHandler } from '@/composables/useDebounce'
import i18n from '@/utils/locale'
import mime from 'mime-types'
import { yup } from '../schema'

const setup = (props, context) => {

  const { root: { $store } = {} } = context

  const {
    id,
    item,
    entries,
  } = toRefs(props)


  const contentType = computed(() => {
    const { name } = item.value
    return mime.lookup(name)
  })

  const schema = computed(() => yup.object({
    name: yup.string()
      .required(i18n.t('Filename required.'))
      .isFilenameWithContentType([contentType.value])
      .fileNotExists(entries.value, item.value.path, i18n.t('File exists.'), item.value.name)
  }))

  const form = ref()
  watch(item, () => {
    form.value = { ...item.value } // dereferenced
  }, { immediate: true })

  const formRef = ref(null)
  const inputRef = ref(null)

  const rename = ref(false)

  const onShow = () => {
    rename.value = true
    nextTick(() => { // after DOM update
      const { $refs: { input: { focus = () => {} } = {} } = {} } = inputRef.value || {}
      focus() // focus input element
    })
  }

  const onCancel = () => {
    form.value = { ...item.value } // dereferenced
    rename.value = false
  }

  const isLoading = computed(() => $store.getters['$_connection_profiles/isLoadingFiles'])
  const isRenaming = ref(false)
  const onRename = () => {
    if (isValid.value) {
      isRenaming.value = true
      const { path } = item.value
      return $store.dispatch(`$_connection_profiles/renameFile`, {
        from: { id: id.value, filename: `${path}/${item.value.name}`.replace('//', '/') },
        to: { id: id.value, filename: `${path}/${form.value.name}`.replace('//', '/')  },
        quiet: true
      })
        .then(onCancel)
        .finally(() => isRenaming.value = false)
    }
  }

  const isValid = useDebouncedWatchHandler([form, entries], () => (!formRef.value || formRef.value.querySelectorAll('.is-invalid').length === 0), { immediate: false })
  const isModified = computed(() => form.value.name !== item.value.name)
  const canRename = computed(() => isValid.value && isModified.value)

  return {
    form,
    formRef,
    inputRef,
    schema,

    isLoading,
    isRenaming,
    rename,
    onShow,
    onCancel,
    onRename,

    canRename
  }
}

export default {
  name: 'inline-name',
  components,
  props,
  setup
}
</script>
