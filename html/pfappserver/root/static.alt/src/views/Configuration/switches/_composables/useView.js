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
  switchGroup: {
    type: String
  }
}

const useView = (props, context) => {

  const {
    id,
    switchGroup,
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
        return i18n.t('Switch {id}', { id: unref(id) })
      case unref(isClone):
        return i18n.t('Clone Switch {id}', { id: unref(id) })
      default:
        return i18n.t('New Switch')
    }
  })

  const titleBadge = computed(() => unref(switchGroup) || unref(form).group)

  const isLoading = computed(() => $store.getters['$_switches/isLoading'])

  const doInit = () => {
    if (!isNew.value) { // existing
      $store.dispatch('$_switches/optionsById', id.value).then(options => {
        const { meta: _meta = {} } = options
        meta.value = _meta
        $store.dispatch('$_switches/getSwitch', id.value).then(_form => {
          if (isClone.value) {
            _form.id = `${_form.id}-${i18n.t('copy')}`
            _form.not_deletable = false
          }
          form.value = _form
        }).catch(() => {
          form.value = {}
        })
      }).catch(() => {
        form.value = {}
        meta.value = {}
      })
    } else { // new
      $store.dispatch('$_switches/optionsBySwitchGroup', switchGroup.value).then(options => {
        const { meta: _meta = {} } = options
        form.value = { ...defaultsFromMeta(_meta), group: switchGroup.value }
        meta.value = _meta
      }).catch(() => {
        form.value = {}
        meta.value = {}
      })
    }
  }

  const doClone = () => $router.push({ name: 'cloneSwitch' })

  const doClose = () => $router.push({ name: 'switches' })

  const doRemove = () => {
    $store.dispatch('$_switches/deleteSwitch', id.value).then(() => doClose())
  }

  const doReset = doInit

  const doSave = () => {
    const closeAfter = actionKey.value
    switch (true) {
      case unref(isClone):
      case unref(isNew):
        $store.dispatch('$_switches/createSwitch', form.value).then(() => {
          if (closeAfter) // [CTRL] key pressed
            doClose()
          else
            $router.push({ name: 'switch', params: { id: form.value.id } })
        })
        break
      default:
        $store.dispatch('$_switches/updateSwitch', form.value).then(() => {
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
    doSave
  }
}

export {
  useViewProps,
  useView
}
