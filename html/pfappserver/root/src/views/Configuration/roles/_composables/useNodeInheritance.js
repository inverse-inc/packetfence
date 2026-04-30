import { computed, ref, watch } from '@vue/composition-api'
import api from '../_api'

export const useNodeInheritance = (items, sortBy, sortDesc) => {

  // items referenced by the page (as parent_id or children) but not on it —
  // fetched lazily so ghost rows have the correct parent_id and depth instead
  // of being pinned to whichever on-page ancestor first lists them
  const extraItems = ref([])
  let fetchEpoch = 0

  const _resolveInheritance = async () => {
    const myEpoch = ++fetchEpoch
    // safety bound: a deep chain still resolves in a small number of round trips
    for (let i = 0; i < 10; i++) {
      if (myEpoch !== fetchEpoch) return // items changed under us
      const all = [ ...(items.value || []), ...extraItems.value ]
      const known = new Set(all.map(it => it.id))
      const referenced = new Set()
      all.forEach(it => {
        if (it.parent_id) referenced.add(it.parent_id)
        if (Array.isArray(it.children)) it.children.forEach(c => referenced.add(c))
      })
      const missing = [ ...referenced ].filter(id => id && !known.has(id))
      if (missing.length === 0) return
      let data
      try {
        data = await api.search({
          limit: missing.length,
          fields: [ 'id', 'parent_id', 'children' ],
          query: {
            op: 'or',
            values: missing.map(id => ({ field: 'id', op: 'equals', value: id }))
          }
        })
      }
      catch (e) { return }
      if (myEpoch !== fetchEpoch) return
      const fetched = (data.items || []).filter(it => !known.has(it.id))
      if (fetched.length === 0) return
      extraItems.value = [ ...extraItems.value, ...fetched ]
    }
  }

  watch(items, () => {
    extraItems.value = []
    _resolveInheritance()
  }, { immediate: true })

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
      return (sortByA || '').toString().localeCompare((sortByB || '').toString()) * sortMod
    else {
      if (parentIdA === idB)
        return 1 // always show before
      else if (parentIdB === idA)
        return -1 // always show after
    }
    return 0 // use natural
  }  

  const _flattenFamilies = (_families) => {
    // sort + mark _last on direct siblings BEFORE flattening descendants,
    // otherwise the deepest grandchild gets _last instead of the last sibling
    const siblings = [ ..._families ].sort(_sortFn)
    return siblings.reduce((families, family, idx) => {
      const isLast = (idx === siblings.length - 1)
      let { _children, ..._family } = family
      if (isLast)
        _family._last = true
      if (_children) {
        const children = _flattenFamilies(_children)
        return [ ...families, _family, ...children ]
      }
      return [ ...families, _family ]
    }, [])
  }

  // an item only seen as `parent_id` or fetched as inheritance filler — rendered
  // greyed-out via these row props
  const GHOST = {
    _children: [], // post-processed
    _match: false, // not found in search
    _rowVariant: 'row-disabled', // CSSable
    not_deletable: true // defer uncertainty
  }

  const itemsTree = computed(() => {
    const _items = items.value || []
    const _extras = extraItems.value || []
    const _itemIds = new Set(_items.map(it => it.id))

    // build associative array for lookups; extras (fetched to fill in
    // inheritance for off-page descendants/ancestors) carry GHOST props
    const associative = [ ..._items, ..._extras ].reduce((map, item) => {
      const { id } = item
      const isExtra = !_itemIds.has(id)
      const _item = isExtra
        ? { ...item, _children: [], ...GHOST }
        : { ...item, _children: [], _match: true }
      return { ...map, [id]: _item }
    }, {})

    // track depth for later processing
    let maxDepth = 0

    // helper: calculate inherent tree depth(s); ghost-child synthesis based
    // on parent.children was removed because that field can list indirect
    // descendants — extras (fetched separately) provide the real parent_id
    const _getDepth = (id) => {
      let depth = 0
      if (id in associative) {
        const { parent_id } = associative[id]
        if (parent_id && parent_id in associative)
          depth = _getDepth(parent_id) + 1
        else if (parent_id) {
          associative[parent_id] = {
            id: parent_id,
            children: [id],
            _depth: 0,
            ...GHOST
          } // ghost parent (parent_id missing entirely from data)
          depth = 1
        }
        else
          depth = 0
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

    // ids of items that are the last child at their depth — used to decide
    // whether an ancestor column should keep drawing a vertical line below
    const lastIds = new Set(flattened.filter(it => it._last).map(it => it.id))

    // decorate items
    const decorated = flattened
      .map(item => {
        const { children = [], _depth, _last } = item || {}
        let _tree = []
        if (_depth > 0) {
          // walk parent chain to collect ancestors (chain[k] = ancestor at depth k)
          const chain = []
          let cur = item
          while (cur && cur.parent_id && associative[cur.parent_id] && chain.length < _depth) {
            cur = associative[cur.parent_id]
            chain.unshift(cur)
          }
          // ancestor columns: blank when that ancestor was a last-child,
          // otherwise a vertical line continues past this row
          for (let i = 0; i < _depth - 1; i++) {
            const ancestor = chain[i + 1]
            _tree.push((ancestor && lastIds.has(ancestor.id))
              ? { name: 'tree-skip', class: 'nav-icon' }
              : { name: 'tree-pass', class: 'nav-icon' }
            )
          }
          // own branch
          _tree.push(_last
            ? { name: 'tree-last', class: 'nav-icon' }
            : { name: 'tree-node', class: 'nav-icon' }
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