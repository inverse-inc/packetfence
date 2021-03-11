<template>
  <b-button-group v-if="samlMetaData">
    <b-button class="ml-1 mr-1" size="sm" variant="outline-secondary" @click="onShowSaml">{{ $t('View Service Provider Metadata') }}</b-button>
    <b-modal v-model="isShowSaml" title="Service Provider Metadata" size="lg" centered cancel-disabled>
      <b-form-textarea ref="samlRef" v-model="samlMetaData" :rows="27" :max-rows="27" readonly></b-form-textarea>
      <template v-slot:modal-footer>
        <b-button variant="secondary" class="mr-1" @click="onHideSaml">{{ $t('Close') }}</b-button>
        <b-button variant="primary" @click="onCopySaml">{{ $t('Copy to Clipboard') }}</b-button>
      </template>
    </b-modal>
  </b-button-group>
</template>
<script>
import { ref, toRefs, watch } from '@vue/composition-api'
import i18n from '@/utils/locale'

const props = {
  id : {
    type: String
  },
  sourceType: {
    type: String
  }
}

const setup = (props, context) => {

  const {
    id,
    sourceType
  } = toRefs(props)

  const { root: { $store } = {} } = context

  const samlMetaData = ref(undefined)

  watch([id, sourceType], () => {
    if (sourceType.value === 'SAML') {
      $store.dispatch('$_sources/getAuthenticationSourceSAMLMetaData', id.value).then(xml => {
        samlMetaData.value = xml
      }).catch(() => {
        samlMetaData.value = undefined
      })
    }
    else {
      samlMetaData.value = undefined
    }
  })

  const samlRef = ref(null)
  const isShowSaml = ref(false)
  const onShowSaml = () => { isShowSaml.value = true }
  const onHideSaml = () => { isShowSaml.value = false }
  const onCopySaml = () => {
    if (document.queryCommandSupported('copy')) {
      const { refs: { samlRef } = {} } = context
      samlRef.$el.select()
      document.execCommand('copy')
      onHideSaml()
      $store.dispatch('notification/info', { message: i18n.t('XML copied to clipboard') })
    }
  }

  return {
    samlMetaData,
    samlRef,
    isShowSaml,
    onShowSaml,
    onHideSaml,
    onCopySaml
  }
}

// @vue/component
export default {
  name: 'button-saml-meta-data',
  inheritAttrs: false,
  props,
  setup
}
</script>
