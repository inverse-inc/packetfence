import { computed, ref } from '@vue/composition-api'

export const useNodeInheritance = (items, sortBy, sortDesc) => {

  const collapsedNodes = ref([])
  const clearExpandedNodes = () => { collapsedNodes.value = [] }
  const _expandNode = id => {
    collapsedNodes.value = collapsedNodes.value.filter(expanded => expanded !== id)
  }
  const _collapseNode = id => {
    if (!collapsedNodes.value.includes(id))
      collapsedNodes.value = [ ...collapsedNodes.value, id ]
  }
  const onToggleNode = id => {
    if (collapsedNodes.value.includes(id))
      _expandNode(id)
    else
      _collapseNode(id)
  }

  const _sortFn =(a, b) => {
    const sortMod = ((sortDesc.value) ? -1 : 1)
    const { [sortBy.value]: sortByA, id: idA, parent_id: parentIdA } = a 
    const { [sortBy.value]: sortByB, id: idB, parent_id: parentIdB } = b
    if (parentIdA === parentIdB)
      return sortByA.toString().localeCompare(sortByB.toString()) * sortMod
    else {
      if (parentIdA === idB)
        return 1 // always show before
      else if (parentIdB === idA)
        return -1 // always show after
    }
    return 0 // use natural
  }  

  const _flattenFamilies = (_families) => {
    return _families.reduce((families, family) => {
      let { _children, ..._family } = family
      if (_children) {
        const children = _flattenFamilies(_children)
          .sort(_sortFn)
        if (children.length > 0)
          children[children.length - 1]._last = true // mark _last
        return [ ...families, _family, ...children ]
      }
      return [ ...families, _family ]
    }, [])
  }

  const itemsTree = computed(() => {
    const _items = items.value

    // build associative array for lookups
    const associative = _items.reduce((items, item) => {
      const { id } = item
      const _item = { 
        ...item, 
        _children: [], // post-processed
        _match: true // found in search
      }
      return { ...items, [id]: _item }
    }, {})

    // an item only seen as `parent_id` or `children`, not `id`
    const GHOST = {
      _children: [], // post-processed
      _match: false, // not found in search
      _rowVariant: 'row-disabled', // CSSable
      not_deletable: true // defer uncertainty
    }

    // track depth for later processing
    let maxDepth = 0

    // helper: calculate inherent tree depth(s)
    const _getDepth = (id) => {
      let depth = 0 // not exists
      if (id in associative) { // exists
        const { parent_id, children } = associative[id]
        if (parent_id && parent_id in associative)
          depth = _getDepth(parent_id) + 1
        else if (parent_id) {
          associative[parent_id] = { 
            id: parent_id,
            children: [id], 
            _depth: 0, 
            ...GHOST
          } // push ghost parent
          depth = 1
        }
        else
          depth = 0 // root
        // opportunistic ghost children handling
        if (children) {
          children.forEach(child => {
            if (!(child in associative)) {
              associative[child] = {
                id: child,
                parent_id: id,
                children: [],
                _depth: depth + 1,
                ...GHOST
              } // push ghost child
              maxDepth = Math.max(maxDepth, depth + 1) // post-process hint
            }
          })
        }
      }
      return depth
    }

    // append inherent depth to all items
    Object.values(associative).forEach(item => {
      const { id } = item
      const depth = _getDepth(id)
      maxDepth = Math.max(maxDepth, depth)
      associative[id]._depth = depth
    })

    // reorganize by family, associate children
    for(let m = maxDepth; m > 0; m--) {
      Object.values(associative)
        .filter(({ _depth }) => _depth === m)
        .forEach(item => {
          const { parent_id } = item
          if (!collapsedNodes.value.includes(parent_id)) // ignore collapsed parent
            associative[parent_id]._children.push(item)
        })
    }

    // organize families
    const families = Object.values(associative)
      .filter(({ _depth }) => _depth === 0) // truncate 
      .sort(_sortFn) // sort root families

    // flatten families
    const flattened = _flattenFamilies(families)

    // decorate items
    const decorated = flattened      
      .map(item => {
        const { children = [], _depth, _last } = item || {}
        let _tree = []
        if (_depth > 0) {
          _tree.push(
            ...(
              new Array(_depth - 1).fill(null)
                .map(() => ({
                  name: 'tree-pass', class: 'nav-icon'
                }))
            ),
            ...((_last)
              ? [{ name: 'tree-last', class: 'nav-icon' }]
              : [{ name: 'tree-node', class: 'nav-icon' }]
            )
          )
        }
        const _icon = ((children && children.length)
          ? { name: 'user-plus', class: 'ml-1 text-black' }
          : { name: 'user', class: 'text-black-50' }
        )
        return { ...item, _tree, _icon }
      })
    return decorated
  }) 

  return {
    collapsedNodes,
    clearExpandedNodes,
    onToggleNode,
    itemsTree
  }
}