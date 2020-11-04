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
  }
}

const useView = (props, context) => {

  const {
    id,
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
        return i18n.t('Domain: <code>{id}</code>', { id: unref(id) })
      case unref(isClone):
        return i18n.t('Clone Domain: <code>{id}</code>', { id: unref(id) })
      default:
        return i18n.t('New Domains')
    }
  })

  const isLoading =  computed(() => $store.getters['$_domains/isLoading'])

  const doInit = () => {
    $store.dispatch('$_domains/options', id.value).then(options => {
      const { meta: _meta = {} } = options
      meta.value = _meta
      if (isNew.value) // new
        form.value = defaultsFromMeta(meta.value)
    }).catch(() => {
      meta.value = {}
    })
    if (!isNew.value) { // existing
      $store.dispatch('$_domains/getDomain', id.value).then(_form => {
        if (isClone.value) {
          _form.id = `${_form.id}-${i18n.t('copy')}`
          _form.not_deletable = false
        }
        form.value = _form
      }).catch(() => {
        form.value = {}
      })
    }
  }

  const doClone = () => $router.push({ name: 'cloneDomain' })

  const doClose = () => $router.push({ name: 'domains' })

  const doRemove = () => $store.dispatch('$_domains/deleteDomain', id.value).then(() => doClose())

  const doReset = doInit

  const doSave = () => {
    const closeAfter = actionKey.value
    switch (true) {
      case unref(isClone):
      case unref(isNew):
        $store.dispatch('$_domains/createDomain', form.value).then(() => {
          if (closeAfter) // [CTRL] key pressed
            $router.push({ name: 'domains', params: { autoJoinDomain: form.value } })
          else
            $router.push({ name: 'domain', params: { id: form.value.id } })
        })
        break
      default:
        $store.dispatch('$_domains/updateDomain', form.value).then(() => {
          if (closeAfter) // [CTRL] key pressed
            $router.push({ name: 'domains', params: { autoJoinDomain: form.value } })
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
