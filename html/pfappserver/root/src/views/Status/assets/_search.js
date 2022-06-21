import makeSearch from '@/store/factory/search'
import { search as nodesNetworkSearch } from '@/views/Nodes/network/_search'

export const useSearch = makeSearch('assetsNodesNetwork', nodesNetworkSearch)