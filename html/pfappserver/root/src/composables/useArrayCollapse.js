import { ref, unref } from '@vue/composition-api'

export default function useArrayCollapse(actionKey, context) {

  const isCollapse = ref(true)
  const isRendered = ref(false) // performance: do not render collapse contents

  const doToggle = () => {
    const toggleAll = unref(actionKey)
    if (toggleAll) {
      const { parent: { $children = [] } = {} } = context
      if (unref(isCollapse))
        $children.map(({ doExpand = () => {} }) => doExpand())
      else
        $children.map(({ doCollapse = () => {} }) => doCollapse())
    }
    else
      (isCollapse.value ? doExpand : doCollapse)()
  }
  const doCollapse = () => isCollapse.value = true
  const doExpand = () => isCollapse.value = false

  const onShow = () => {
    isRendered.value = true
  }
  const onHidden = () => {
    isRendered.value = false
  }

  return {
    isCollapse,
    isRendered,

    doToggle,
    doCollapse,
    doExpand,
    onShow,
    onHidden
  }
}
