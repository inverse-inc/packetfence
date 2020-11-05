import { computed, ref, toRefs, unref, watch } from '@vue/composition-api'
import { useView as useBaseView, useViewProps as useBaseViewProps } from '@/composables/useView'
import i18n from '@/utils/locale'
import {
  defaultsFromMeta
} from '../../_config/'

const useViewProps = {
  ...useBaseViewProps,

  id: {
    type: String
  },
  sourceType: {
    type: String
  }
}

const useView = (props, context) => {

  const {
    id,
    sourceType,
    isClone,
    isNew
  } = toRefs(props) // toRefs maintains reactivity w/ destructuring
  const { root: { $store, $router } = {} } = context

  const {
    rootRef,
    form,
    meta,
    customProps,
    actionKey,
    escapeKey,
    isDeletable,
    isValid
  } = useBaseView(props, context)

  const titleLabel = computed(() => {
    switch (true) {
      case !unref(isNew) && !unref(isClone):
        return i18n.t('Authentication Source: <code>{id}</code>', { id: unref(id) })
      case unref(isClone):
        return i18n.t('Clone Authentication Source: <code>{id}</code>', { id: unref(id) })
      default:
        return i18n.t('New Authentication Source')
    }
  })

  const titleBadge = computed(() => unref(sourceType) || unref(form).type)

  const isLoading = computed(() => $store.getters['$_sources/isLoading'])

  const samlRef = ref(null)
  const samlMetaData = ref(undefined)
  const isSaml = ref(false)
  const showSaml = () => { isSaml.value = true }
  const hideSaml = () => { isSaml.value = false }
  const copySaml = () => {
    if (document.queryCommandSupported('copy')) {
      const { refs: { samlRef } = {} } = context
      samlRef.$el.select()
      document.execCommand('copy')
      hideSaml()
      $store.dispatch('notification/info', { message: i18n.t('XML copied to clipboard') })
    }
  }

  const doInit = () => {
    samlMetaData.value = undefined
    if (!isNew.value) { // existing
      $store.dispatch('$_sources/optionsById', id.value).then(options => {
        const { meta: _meta = {} } = options
        meta.value = _meta
        $store.dispatch('$_sources/getAuthenticationSource', id.value).then(_form => {
          if (isClone.value) {
            _form.id = `${_form.id}-${i18n.t('copy')}`
            _form.not_deletable = false
          }
          form.value = _form
          if (_form.type === 'SAML') {
            $store.dispatch('$_sources/getAuthenticationSourceSAMLMetaData', id.value).then(xml => {
              samlMetaData.value = xml
            })
          }
        }).catch(() => {
          form.value = {}
        })
      }).catch(() => {
        form.value = {}
        meta.value = {}
      })
    } else { // new
      $store.dispatch('$_sources/optionsBySourceType', unref(sourceType)).then(options => {
        const { meta: _meta = {} } = options
        form.value = { ...defaultsFromMeta(_meta), type: unref(sourceType) }
        meta.value = _meta
      }).catch(() => {
        form.value = {}
        meta.value = {}
      })
    }
  }

  const doClone = () => $router.push({ name: 'cloneAuthenticationSource' })

  const doClose = () => $router.push({ name: 'sources' })

  const doRemove = () => $store.dispatch('$_sources/deleteAuthenticationSource', id.value).then(() => doClose())

  const doReset = doInit

  const doSave = () => {
    const closeAfter = actionKey.value
    switch (true) {
      case unref(isClone):
      case unref(isNew):
        $store.dispatch('$_sources/createAuthenticationSource', form.value).then(() => {
          if (closeAfter) // [CTRL] key pressed
            doClose()
          else
            $router.push({ name: 'source', params: { id: form.value.id } })
        })
        break
      default:
        $store.dispatch('$_sources/updateAuthenticationSource', form.value).then(() => {
          if (closeAfter) // [CTRL] key pressed
            doClose()
        })
        break
    }
  }

  watch(escapeKey, () => doClose())

  watch(props, () => doInit(), { deep: true, immediate: true })

  return {
    rootRef,

    form,
    meta,
    customProps,
    titleLabel,
    titleBadge,

    actionKey,
    isLoading,
    isDeletable,
    isValid,

    doInit,
    doClone,
    doClose,
    doRemove,
    doReset,
    doSave,

    // section specific variable
    samlRef,
    samlMetaData,
    isSaml,
    showSaml,
    hideSaml,
    copySaml
  }
}

export {
  useViewProps,
  useView
}
