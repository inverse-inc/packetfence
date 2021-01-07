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
 *    <pf-form-upload @files="files = $event"></pf-form-upload>
 *  </template>
 *
 * Extended Usage:
 *
 *  <template>
 *    <pf-form-upload @files="files = $event"
 *      accept="text/*"
 *      :multiple="true"
 *      :cumulative="true"
 *      title="Upload File"
 *      read-as-text
 *    ></pf-form-upload>
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
 *   <pf-form-upload @files="files = $event">
 *     <b-button><icon variant="primary" name="upload"></icon> {{ $t('Custom Styled Button') }}</b-button>
 *   </pf-form-upload>
 *
-->
<template>
  <div :class="getClass" :title="title">
    <label class="pf-form-upload mb-0">
      <b-form ref="uploadform" @submit.prevent>
        <!-- MUTLIPLE UPLOAD -->
        <input v-if="multiple" type="file" @change="uploadFiles" :accept="accept" title=" " multiple/>
        <!-- SINGLE UPLOAD -->
        <input v-else type="file" @change="uploadFiles" :accept="accept" title=" "/>
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
        <template v-slot:aside><icon name="exclamation-triangle" scale="2" class="text-danger"></icon></template>
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
import FileStore from '@/store/base/file'

export default {
  name: 'pf-form-upload',
  props: {
    accept: {
      type: String,
      default: '*/*'
    },
    encoding: {
      type: String,
      default: 'utf-8'
    },
    multiple: {
      type: Boolean,
      default: false
    },
    cumulative: {
      type: Boolean,
      default: false
    },
    title: {
      type: String,
      default: ''
    },
    readAsText: {
      type: Boolean,
      default: false
    }
  },
  data () {
    return {
      files: [],
      showErrorModal: false
    }
  },
  methods: {
    storeNameFromFile (file) {
      const { lastModified, name } = file
      return `file/${name}/${lastModified}`
    },
    uploadFiles (event) {
      if (!this.cumulative) {
        this.files = []
      }
      const { target: { files } = {} } = event
      Array.from(files).forEach((file) => {
        const fileIndex = this.files.findIndex(f => f.name === file.name && f.lastModified === file.lastModified)
        if (fileIndex > -1) {
          this.$emit('focus', fileIndex)
        } else {
          const storeName = this.storeNameFromFile(file)
          if (!this.$store.state[storeName]) { // Register store module only once
            const fileStore = new FileStore(file)
            this.$store.registerModule(storeName, fileStore.module())
          }
          if (this.readAsText) {
            this.$store.dispatch(`${storeName}/readAsText`)
          }
          this.$set(this.files, this.files.length, this.$store.getters[`${storeName}/file`])
        }
      })
      // clear the input to allow re-upload
      this.$refs.uploadform.reset()
    },
    closeFile (file) {
      const fileIndex = this.files.findIndex(f => f.name === file.name && f.lastModified === file.lastModified)
      if (fileIndex > -1) {
        const storeName = this.storeNameFromFile(this.files[fileIndex])
        if (this.$store.state[storeName]) {
          this.$store.unregisterModule(storeName)
        }
        this.files.splice(fileIndex, 1)
      }
    },
    clearFirstError () {
      this.showErrorModal = false
      this.$nextTick(() => {
        const fileIndex = this.files.findIndex(file => file.error)
        const file = this.files[fileIndex]
        this.closeFile(file)
      })
    }
  },
  computed: {
    getClass () {
      return 'pf-form-upload-container ' + ((this.class)
        ? this.class
        : 'btn btn-outline-primary'
      )
    },
    errors () {
      return this.files.filter(file => file.error)
    },
    firstError () {
      return (this.errors.length > 0) ? this.errors[0] : false
    }
  },
  mounted () {
    this.files = []
  },
  watch: {
    firstError: {
      handler: function (a) {
        if (a) {
          this.showErrorModal = true
        }
      },
      deep: true
    },
    files: {
      handler: function (a) {
        if (a.length) {
          this.$emit('files', a.map(file => {
            return { ...file, ...{ storeName: this.storeNameFromFile(file), close: () => { this.closeFile(file) } } }
          }))
          setTimeout(() => { // $nextTick fails
            this.$emit('focus', a.length - 1)
          }, 300)
        }
      },
      deep: true
    }
  }
}
</script>

<style lang="scss" scoped>
/**
 * Overlap the default <file/> (top) and the <slot/> (bottom)
 *  where <file/> opacity is 0, permitting click events while
 *  hiding <file/> and allowing <slot/> seethrough for styling.
**/
.pf-form-upload-container {
  position: relative;
  display: inline-block;
}
.pf-form-upload input[type="file"] {
  opacity: 0;
  position: absolute;
  top: 0px;
  left: 0px;
  width: 100%;
  height: 100%;
  /* hide mouseover tooltip */
  color: transparent;
}
.pf-form-upload-container:hover,
.pf-form-upload input[type="file"]:hover {
  cursor: pointer;
}
</style>
