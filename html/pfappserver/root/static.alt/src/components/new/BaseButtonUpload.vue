<template>
  <div class="base-button-upload" :title="title">
    <label class="base-button-upload-label mb-0">
      <b-form ref="formRef" @submit.prevent>
        <!-- MUTLIPLE UPLOAD -->
        <input v-if="multiple"
          type="file" @change="doUpload" :accept="accept" title=" " multiple/>
        <!-- SINGLE UPLOAD -->
        <input v-else
          ref="inputRef"
          type="file" @change="doUpload" :accept="accept" title=" "/>
      </b-form>
    </label>
    <slot>
      {{ $i18n.t('Upload') }}
    </slot>
    <b-modal v-if="showError" v-model="showError" centered
      :title="$i18n.t('Upload Error')"
      @hide="doSkipError"
    >
      <b-media>
        <template v-slot:aside><icon name="exclamation-triangle" scale="2" class="text-danger"></icon></template>
        <h4>{{ firstError.name }}</h4>
        <p class="font-weight-light mt-3 mb-0">{{ firstError.error.message }}</p>
        <p class="font-weight-light mt-3 mb-0 text-pre text-black-50">Ref: {{ firstError.error.name }} (#{{ firstError.error.code}})</p>
      </b-media>
      <template v-slot:modal-footer>
        <b-button variant="primary" @click="doSkipError">{{ $i18n.t('Continue') }}</b-button>
      </template>
    </b-modal>
  </div>
</template>
<script>
export const props = {
  accept: {
    type: String,
    default: '*/*'
  },
  cumulative: {
    type: Boolean
  },
  disabled: {
    type: Boolean
  },
  multiple: {
    type: Boolean
  },
  readAsText: {
    type: Boolean
  },
  title: {
    type: String
  },
  variant: {
    type: String,
    default: 'primary'
  }
}

import { computed, nextTick, ref, toRefs, watch } from '@vue/composition-api'
import mime from 'mime-types'
import FileStore from '@/store/base/file'
import i18n from '@/utils/locale'

const setup = (props, context) => {

  const {
    accept,
    cumulative,
    isLoading,
    readAsText,
    multiple
  } = toRefs(props)

  const { emit, refs, root: { $store } = {} } = context

  const formRef = ref(null)

  // for some unknown reason `files` loses scope
  const $files = ref([])

  watch($files, files => {
    const filesMapped = files.map(file => ({ ...file, storeName: storeNameFromFile(file), close: () => { doClose(file) } }))
    emit('files', filesMapped)
    if (!multiple.value && readAsText.value && filesMapped[0] && filesMapped[0].result)
      emit('input', filesMapped[0].result)
    if (files.length)
      emit('focus', files.length - 1)
  }, { deep: true })

  const errors = computed(() => $files.value.filter(file => file.error))

  const showError = ref(false)

  const firstError = computed(() => (errors.value.length > 0) ? errors.value[0] : false)

  watch(firstError, firstError => {
    if (firstError)
      showError.value = true
  }, { deep: true })

  const isAccept = (file) => {
    const { name } = file
    const contentType = mime.lookup(name).replace(/ /g, '').toLowerCase() // case insensitive
    const accepted = accept.value.replace(/ /g, '').split(',')
      .filter(type => type.toLowerCase()) // ignore multiple commas, case insensitive
      .filter(type => {
        const [ contentTypeMs, contentTypeLs ] = contentType.split('/')
        const [ typeMs, typeLs ] = type.split('/')
        if (contentTypeMs === typeMs && (typeLs === '*' || contentTypeLs === typeLs))
          return true
      })
    return accepted.length > 0
  }

  const storeNameFromFile = (file) => {
    const { lastModified, name } = file
    return `file/${name}/${lastModified}`
  }

  const doReset = () => {
    refs.formRef.reset()
  }

  const doUpload = event => {
    if (!cumulative.value)
      $files.value = []
    const { target: { files } = {} } = event
    Array.from(files).forEach(file => {
      const fileIndex = $files.value.findIndex(f => f.name === file.name && f.lastModified === file.lastModified)
      if (fileIndex > -1) // already exists
        emit('focus', fileIndex)
      else {
        if (isAccept(file)) { // contentType accepted
          const storeName = storeNameFromFile(file)
          if (!$store.state[storeName]) { // register store module only once
            const fileStore = new FileStore(file, accept.value)
            $store.registerModule(storeName, fileStore.module())
          }
          if (readAsText.value)
            $store.dispatch(`${storeName}/readAsText`)
          $files.value.push($store.getters[`${storeName}/file`])
        }
        else { // contentType not accepted
          $store.dispatch('notification/danger', {
            icon: 'upload',
            message: i18n.t('Invalid file, only "<code>{contentTypes}</code>" content-type(s) are accepted.', {
              contentTypes: accept.value
            }),
            url: file.name
          })

          // dump additional info for remote debugging
          // eslint-disable-next-line
          console.error(`Ignored ${file.name} with content-type ${mime.lookup(file.name)}`)
        }
      }
    })
    // clear the input to allow re-upload
    doReset()
  }

  const doClose = file => {
    const fileIndex = $files.value.findIndex(f => f.name === file.name && f.lastModified === file.lastModified)
    if (fileIndex > -1) {
      const storeName = storeNameFromFile($files.value[fileIndex])
      if ($store.state[storeName])
        $store.unregisterModule(storeName)
      $files.value.splice(fileIndex, 1)
    }
  }

  const doSkipError = () => {
    showError.value = false
    nextTick(() => {
      const fileIndex = $files.value.findIndex(file => file.error)
      doClose($files.value[fileIndex])
    })
  }

  return {
    // template ref
    formRef,

    // state
    showError,
    firstError,

    // methods
    doUpload,
    doSkipError
  }
}

// @vue/component
export default {
  name: 'base-button-upload',
  inheritAttrs: false,
  props,
  setup
}
</script>
<style lang="scss">
/**
 * Overlap the default <file/> (top) and the <slot/> (bottom)
 *  where <file/> opacity is 0, permitting click events while
 *  hiding <file/> and allowing <slot/> seethrough for styling.
**/
.base-button-upload {
  position: relative;
  display: inline-block;
  height: 100%;
  & > .base-button-upload-label input[type="file"] {
    opacity: 0;
    position: absolute;
    top: 0px;
    left: 0px;
    width: 100%;
    height: 100%;
    /* hide mouseover tooltip */
    color: transparent;
  }
  & > .fa-icon {
    height: 100%;
  }
}
.base-button-upload:hover,
.base-button-upload-label input[type="file"]:hover {
  cursor: pointer;
}
</style>
