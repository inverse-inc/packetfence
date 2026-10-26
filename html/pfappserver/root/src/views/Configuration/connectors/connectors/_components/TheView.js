import {
  BaseView,

  FormButtonBar,
  TheForm,
  TheHeader
} from './'

const components = {
  ...useViewCollectionItemComponents,
  FormButtonBar,
  TheForm
}

import { computed, provide, watch } from '@vue/composition-api'
import { renderHOCWithScopedSlots } from '@/components/new/'
import {
  useViewCollectionItem,
  useViewCollectionItemComponents,
  useViewCollectionItemProps as props
} from '../../../_composables/useViewCollectionItem'
import * as collection from '../_composables/useCollection'
import { useRemoteStatus } from '../_composables/useRemoteStatus'
import { useTabs } from '../_composables/useTabs'

const setup = (props, context) => {

  const viewCollectionItem = useViewCollectionItem(collection, props, context)
  const {
    isCloneable: _isCloneable,
    isDeletable: _isDeletable,
    isSaveable: _isSaveable
  } = viewCollectionItem

  // live state of the connector-remote, shared with the header and the tabs
  const remote = useRemoteStatus(props, context)
  provide('connectorRemote', remote)

  const tabs = useTabs(props, context)
  provide('connectorTabs', tabs)

  // quick launch from the fleet diagram (?action=): open the DNS lookup, or
  // the terminal / restart confirmation, once; the action is removed from
  // the URL so a reload doesn't repeat it
  const { root } = context
  const { query: { action } = {} } = root.$route || {}
  if (action) {
    const query = Object.fromEntries(Object.entries(root.$route.query).filter(([key]) => key !== 'action'))
    root.$router.replace({ query }).catch(() => {})
    if (action === 'dns')
      tabs.networkingView.value = 'dns'
    else if (action === 'restart' && remote.canUpdate.value)
      remote.showRestartModal.value = true
    else if (action === 'terminal' && remote.canUpdate.value) {
      // the code prompt needs the connector's terminal settings; without TOTP
      // the terminal tab can only be opened from a click on the page itself
      // (popup blocker), so the Troubleshooting tab is just shown
      const stop = watch(remote.system, system => {
        if (!system)
          return
        stop()
        if (remote.isConnected.value && remote.isTerminalEnabled.value && system.terminal_totp !== false)
          remote.openTerminal()
      })
    }
  }

  // the form buttons only apply to the Settings tab, the other tabs are
  // read-only: no footer at all
  const { isSettings } = tabs
  const isSaveable = computed(() => isSettings.value && _isSaveable.value)
  const isCloneable = computed(() => isSettings.value && _isCloneable.value)
  const isDeletable = computed(() => isSettings.value && _isDeletable.value)
  const isFooterHidden = computed(() => !isSettings.value)

  return {
    ...viewCollectionItem,
    isSaveable,
    isCloneable,
    isDeletable,
    isFooterHidden
  }
}

const render = renderHOCWithScopedSlots(BaseView, { components, props, setup }, {
  headerAppend: TheHeader
})

// @vue/component
export default {
  name: 'the-view',
  extends: BaseView,
  inheritAttrs: false,
  props,
  render
}
