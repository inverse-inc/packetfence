<template>
  <div class="file-upload-container">
    <label class="file-upload mb-0">
      <b-form ref="uploadform" @submit.prevent>
        <!-- MUTLIPLE UPLOAD -->
        <input v-if="multiple" type="file" @change="uploadFiles" :accept="accept" :title="$t('Click to upload')" multiple/>
        <!-- SINGLE UPLOAD -->
        <input v-else type="file" @change="uploadFiles" :accept="accept" :title="$t('Click to upload')"/>
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
    }
  },
  methods: {
    uploadFiles (event) {
      this.files = []
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
            if (this.files.length === files.length) {
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
.file-upload,
.file-upload input[type="file"] {
  opacity: 0;
  position: absolute;
  width: 100%;
  height: 100%;
}
.file-upload input[type="file"]:hover {
  cursor: pointer;
}
</style>
