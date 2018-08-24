/**
 * Component to pseudo-upload and access local files. Supports multiple files,
 *  drag-and-drop and restrict by mime-type(s).
 *
 * Basic Usage:
 *
 *  <template>
 *    <pf-form-upload @load="files = $event"></pf-form-upload>
 *  </template>
 *
 * Properties:
 *
 *    `accept`: (string) -- comma separated list of allowed mime type(s) (default: */*)
 *      eg: text/plain, application.json
 *      eg: text/*, application/*
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
 *
 *    `title` (string) -- optional title for mouseover hint (default: null)
 *
 * Events:
 *
 *    @load: emitted w/ `files` after all uploads are processed, contains an array
 *      of liternal object, one-per-file (see: `files`  property).
 *
 * Styling:
 *
 *   The optional child elements (slot) can be used to restyle the upload button
 *
 *   <pf-form-upload @load="files = $event">
 *     <b-button><icon variant="primary" name="upload"></icon> {{ $t('Custom Styled Button') }}</b-button>
 *   </pf-form-upload>
 *
**/
<template>
  <div class="file-upload-container">
    <label class="file-upload mb-0">
      <b-form ref="uploadform" @submit.prevent>
        <!-- MUTLIPLE UPLOAD -->
        <input v-if="multiple" type="file" @change="uploadFiles" :accept="accept" :title="title" multiple/>
        <!-- SINGLE UPLOAD -->
        <input v-else type="file" @change="uploadFiles" :accept="accept" :title="title"/>
      </b-form>
    </label>
    <slot>
      <b-button><icon name="upload"></icon> {{ $t('Upload') }}</b-button>
    </slot>
  </div>
</template>

<script>
export default {
  name: 'pf-form-upload',
  props: {
    accept: {
      type: String,
      default: '*/*'
    },
    multiple: {
      type: Boolean,
      default: false
    },
    files: {
      type: Array,
      default: []
    },
    cumulative:  {
      type: Boolean,
      default: false
    },
    title: {
      type: String,
      default: null
    }
  },
  methods: {
    uploadFiles (event) {
      if (!this.cumulative) {
        this.files = []
      }
      const files = event.target.files
      Array.from(files).forEach((file, index, files) => {
        let reader = new FileReader()
        reader.onload = ((localfile) => {
          return (e) => {
            this.files.push({
              result: e.target.result,
              lastModified: localfile.lastModified,
              name: localfile.name,
              size: localfile.size,
              type: localfile.type
            })
            if (this.cumulative || this.files.length === files.length) {
              this.$emit('load', this.files)
            }
          }
        })(file)
        reader.readAsText(file)
        // reader.readAsDataURL(file)
      })
      // clear the input to allow re-upload
      this.$refs.uploadform.reset()
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
.file-upload-container {
  position: relative;
  display: inline-block;
}
.file-upload input[type="file"] {
  opacity: 0;
  position: absolute;
  top: 0px;
  left: 0px;
  width: 100%;
  height: 100%;
}
.file-upload input[type="file"]:hover {
  cursor: pointer;
}
</style>
