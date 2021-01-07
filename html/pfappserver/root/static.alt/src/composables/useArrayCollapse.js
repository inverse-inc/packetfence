import { ref, unref } from '@vue/composition-api'

export default function useArrayCollapse(actionKey, context) {

  const isCollapse = ref(true)
  const isRendered = ref(false) // performance: do not render collapse contents

  const onToggle = () => {
    const toggleAll = unref(actionKey)
    if (toggleAll) {
      const { parent: { $children = [] } = {} } = context
      if (unref(isCollapse))
        $children.map(({ onExpand = () => {} }) => onExpand())
      else
        $children.map(({ onCollapse = () => {} }) => onCollapse())
    }
    else
      (isCollapse.value ? onExpand : onCollapse)()
  }
  const onCollapse = () => isCollapse.value = true
  const onExpand = () => isCollapse.value = false

  const onShow = () => {
    isRendered.value = true
  }
  const onHidden = () => {
    isRendered.value = false
  }

  return {
    isCollapse,
    isRendered,

    onToggle,
    onCollapse,
    onExpand,
    onShow,
    onHidden
  }
}
