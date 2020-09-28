import { computed, toRefs, unref, watch } from '@vue/composition-api'
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
        return i18n.t('Authentication Source {id}', { id: unref(id) })
      case unref(isClone):
        return i18n.t('Clone Authentication Source {id}', { id: unref(id) })
      default:
        return i18n.t('New Authentication Source')
    }
  })

  const titleBadge = computed(() => unref(sourceType) || unref(form).type)

  const isLoading = computed(() => $store.getters['$_sources/isLoading'])

  const doInit = () => {
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
/*
          if (form.type === 'SAML') {
            $store.dispatch('$_sources/getAuthenticationSourceSAMLMetaData', id.value).then(xml => {
              this.samlMetaData = xml
            })
          }
*/
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

  const doRemove = () => {
    $store.dispatch('$_sources/deleteRole', id.value).then(() => {
      $router.push({ name: 'sources' })
    })
  }

  const doReset = doInit

  const doSave = () => {
    const closeAfter = actionKey.value
    switch (true) {
      case unref(isClone):
      case unref(isNew):
        $store.dispatch('$_sources/createRole', form.value).then(() => {
          if (closeAfter) // [CTRL] key pressed
            $router.push({ name: 'sources' })
          else
            $router.push({ name: 'role', params: { id: form.value.id } })
        })
        break
      default:
        $store.dispatch('$_sources/updateRole', form.value).then(() => {
          if (closeAfter) // [CTRL] key pressed
            $router.push({ name: 'roles' })
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
    doSave
  }
}

export {
  useViewProps,
  useView
}
