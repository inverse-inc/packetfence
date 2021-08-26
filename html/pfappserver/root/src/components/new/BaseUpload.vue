<!--
 * Component to pseudo-upload and access local files using FileReader.
 *
 * Supports:
 *  multiple files
 *  restrict by mime-type(s) and/or file extension(s)
 *  automatic processing of file contents into result
 *
 * Basic Usage:
 *
 *  <template>
 *    <base-upload @files="files = $event" />
 *  </template>
 *
 * Extended Usage:
 *
 *  <template>
 *    <base-upload @files="files = $event"
 *      accept="text/*"
 *      :multiple="true"
 *      :cumulative="true"
 *      title="Upload File"
 *      read-as-text
 *    />
 *  </template>
 *
 * Properties:
 *
 *    `accept`: (string) -- comma separated list of allowed mime type(s) or file extension(s) (default: */*)
 *      eg: text/plain, application/json, .csv
 *      eg: text/*, application/*, .csv
 *
 *    `multiple`: (true|false) -- allow multiple files (default: false)
 *
 *    `files`: (array) -- [
 *      {
 *        result: (string) -- the file contents,
 *        lastModified: (int) -- timestamp-milliseconds of when the file was last modified,
 *        name: (string) -- the original filename (no path),
 *        size: (int) -- the file size in Bytes,
 *        type: (string) -- the mime-type of the file (eg: 'text/plain').
 *      },
 *      ...
 *    ]
 *
 *    `cumulative` (true|false) -- `files` accumulates with each upload (default: false)
 *      true: @files event emitted after every file is uploaded, `files` is never reset.
 *      false: @files event emitted once after all files are uploaded, `files` is reset on each upload.
 *
 *    `title` (string) -- optional title for mouseover hint (default: null)
 *
 *    `read-as-text' (boolean) -- automatically process the file contents into result (default: false)
 *
 * Events:
 *
 *    @files: emitted w/ `files` after all uploads are processed, contains an array
 *      of literal object, one-per-file (see: `files`  property).
 *
 * Slots:
 *
 *   The optional child elements (slot) can be used to restyle the upload button
 *
 *   <base-upload @files="files = $event">
 *     <b-button><icon variant="primary" name="upload" /> {{ $t('Custom Styled Button') }}</b-button>
 *   </base-upload>
 *
-->
<template>
  <div :class="rootClass" :title="title">
    <label class="base-upload mb-0">
      <b-form ref="uploadform" @submit.prevent>
        <!-- MUTLIPLE UPLOAD -->
        <input v-if="multiple" type="file" @change="uploadFiles" :accept="accept" title=" " multiple />
        <!-- SINGLE UPLOAD -->
        <input v-else type="file" @change="uploadFiles" :accept="accept" title=" " />
      </b-form>
    </label>
    <slot>
      {{ $t('Upload') }}
    </slot>
    <b-modal v-if="showErrorModal" v-model="showErrorModal" centered
      :title="$t('Upload Error')"
      @hide="clearFirstError()"
    >
      <b-media>
        <template v-slot:aside><icon name="exclamation-triangle" scale="2" class="text-danger" /></template>
        <h4>{{ firstError.name }}</h4>
        <p class="font-weight-light mt-3 mb-0">{{ firstError.error.message }}</p>
        <p class="font-weight-light mt-3 mb-0 text-pre text-black-50">Ref: {{ firstError.error.name }} (#{{ firstError.error.code}})</p>
      </b-media>
      <template v-slot:modal-footer>
        <b-button variant="primary" @click="clearFirstError()">{{ $t('Continue') }}</b-button>
      </template>
    </b-modal>
  </div>
</template>

<script>
const props = {
  accept: {
    type: String,
    default: '*/*'
  },
  encoding: {
    type: String,
    default: 'utf-8'
  },
  multiple: {
    type: Boolean
  },
  cumulative: {
    type: Boolean
  },
  title: {
    type: String
  },
  readAsText: {
    type: Boolean
  }
}

import { computed, nextTick, ref, toRefs, watch } from '@vue/composition-api'
import FileStore from '@/store/base/file'
const setup = (props, context) => {

  const {
    cumulative,
    readAsText
  } = toRefs(props)

  const { attrs, emit, refs, root: { $store } = {} } = context

  const files = ref([])
  watch(files, () => {
    if (files.value.length) {
      emit('files', files.value.map(file => ({ ...file, ...{ storeName: storeNameFromFile(file), close: () => closeFile(file) } })))
      setTimeout(() => { // $nextTick fails
        emit('focus', files.value.length - 1)
      }, 300)
    }
  }, { deep: true })

  const rootClass = computed(() => {
    const extraClass = (attrs.class)
      ? attrs.class
      : 'btn btn-outline-primary'
    return `base-upload-container ${extraClass}`
  })
  const errors = computed(() => files.value.filter(file => file.error))
  const firstError = computed(() => (errors.value.length > 0) ? errors.value[0] : false)
  const showErrorModal = ref(false)
  watch(firstError, () => {
    showErrorModal.value = !!firstError.value
  })

  const storeNameFromFile = file => {
    const { lastModified, name } = file
    return `file/${name}/${lastModified}`
  }

  const uploadFiles = event => {
    if (!cumulative.value)
      files.value = []
    const { target: { files: _files } = {} } = event
    Array.from(_files).forEach(file => {
      const fileIndex = files.value.findIndex(f => f.name === file.name && f.lastModified === file.lastModified)
      if (fileIndex > -1)
        emit('focus', fileIndex)
      else {
        const storeName = storeNameFromFile(file)
        if (!$store.state[storeName]) { // Register store module only once
          const fileStore = new FileStore(file)
          $store.registerModule(storeName, fileStore.module())
        }
        if (readAsText.value)
          $store.dispatch(`${storeName}/readAsText`)
        files.value.push($store.getters[`${storeName}/file`])
      }
    })
    // clear the input to allow re-upload
    refs.uploadform.reset()
  }

  const closeFile = file => {
    const fileIndex = files.value.findIndex(f => f.name === file.name && f.lastModified === file.lastModified)
    if (fileIndex > -1) {
      const storeName = storeNameFromFile(files.value[fileIndex])
      if ($store.state[storeName])
        $store.unregisterModule(storeName)
      files.value.splice(fileIndex, 1)
    }
  }

  const clearFirstError = () => {
    showErrorModal.value = false
    nextTick(() => {
      const fileIndex = files.value.findIndex(file => file.error)
      const file = files.value[fileIndex]
      closeFile(file)
    })
  }

  return {
    files,
    rootClass,
    errors,
    firstError,
    showErrorModal,
    storeNameFromFile,
    uploadFiles,
    closeFile,
    clearFirstError
  }
}

// @vue/component
export default {
  name: 'base-upload',
  props,
  setup
}
</script>

<style lang="scss" scoped>
/**
 * Overlap the default <file /> (top) and the <slot /> (bottom)
 *  where <file /> opacity is 0, permitting click events while
 *  hiding <file /> and allowing <slot /> seethrough for styling.
**/
.base-upload-container {
  position: relative;
  display: inline-block;
}
.base-upload input[type="file"] {
  opacity: 0;
  position: absolute;
  top: 0px;
  left: 0px;
  width: 100%;
  height: 100%;
  /* hide mouseover tooltip */
  color: transparent;
}
.base-upload-container:hover,
.base-upload input[type="file"]:hover {
  cursor: pointer;
}
</style>
