<template>
  <b-card no-body class="the-threads-card">
    <b-card-header class="d-flex align-items-center">
      <h5 class="mb-0 text-truncate" v-t="'Conversations'" />
      <b-button variant="link" class="ml-auto the-threads-new" @click="onNew"
        v-b-tooltip.hover.bottom.d300 :title="$t('New conversation')" :aria-label="$t('New conversation')">
        <icon name="plus" />
      </b-button>
    </b-card-header>
    <div class="p-2 the-threads-filters">
      <b-form-input v-model="query" size="sm" :placeholder="$t('Search conversations')" debounce="200" />
      <b-form-select v-model="sort" size="sm" class="mt-1" :options="sortOptions" />
    </div>
    <b-list-group flush class="the-threads">
      <b-list-group-item v-if="!threads.length" class="text-muted small">{{ $t('No saved conversations yet.') }}</b-list-group-item>
      <b-list-group-item v-else-if="query && !list.length" class="text-muted small">{{ $t('No conversation matches.') }}</b-list-group-item>
      <b-list-group-item v-for="thread in list" :key="thread.id" button
        class="the-thread d-flex flex-wrap align-items-center py-2" :class="{ 'is-active': thread.id === threadId }"
        :aria-current="thread.id === threadId ? 'true' : null"
        @click="onOpen(thread.id)">
        <span class="text-truncate w-100 the-thread-title">{{ thread.title }}</span>
        <small class="text-nowrap text-muted flex-grow-1">
          <timeago v-if="thread.updated" :datetime="thread.updated * 1000" :auto-update="60" :locale="$i18n.locale" />
          <template v-if="thread.match_count"> &middot; {{ $tc('{count} match | {count} matches', thread.match_count, { count: thread.match_count }) }}</template>
        </small>
        <b-button size="sm" variant="link" class="p-0 ml-1 the-thread-delete"
          v-b-tooltip.hover.right.d300 :title="$t('Delete conversation')" :aria-label="$t('Delete conversation')"
          @click.stop="onDelete(thread.id)">
          <icon name="trash-alt" />
        </b-button>
        <small v-if="query && thread.snippet" class="w-100 text-truncate font-italic">{{ thread.snippet }}</small>
      </b-list-group-item>
    </b-list-group>
  </b-card>
</template>

<script>
import { computed, ref, watch } from '@vue/composition-api'
import i18n from '@/utils/locale'

const sortOptions = [
  { value: 'newest', text: i18n.t('Newest first') },
  { value: 'oldest', text: i18n.t('Oldest first') },
  { value: 'relevance', text: i18n.t('Best match') },
  { value: 'frequency', text: i18n.t('Most messages') },
  { value: 'az', text: i18n.t('Title A-Z') }
]

const comparators = {
  newest: (a, b) => (b.updated || 0) - (a.updated || 0),
  oldest: (a, b) => (a.updated || 0) - (b.updated || 0),
  frequency: (a, b) => (b.msg_count || 0) - (a.msg_count || 0),
  az: (a, b) => (a.title || '').localeCompare(b.title || ''),
  relevance: (a, b) => (b.match_count || 0) - (a.match_count || 0) || (b.updated || 0) - (a.updated || 0)
}

const setup = (props, context) => {
  const { root: { $store } = {} } = context

  const threads = computed(() => $store.state.$_assistant.threads)
  const threadId = computed(() => $store.state.$_assistant.threadId)
  const searchResults = computed(() => $store.state.$_assistant.searchResults)

  // the search hits title AND message bodies on the server
  const query = ref('')
  watch(query, q => $store.dispatch('$_assistant/searchThreads', (q || '').trim()))

  const sort = ref('newest')
  const list = computed(() => {
    const q = (query.value || '').trim()
    const items = ((q && searchResults.value) ? searchResults.value : threads.value).slice()
    // with a query, default to relevance unless another sort was picked
    return items.sort(comparators[(q && sort.value === 'newest') ? 'relevance' : sort.value])
  })

  const onNew = () => $store.dispatch('$_assistant/newThread')
  const onOpen = id => $store.dispatch('$_assistant/openThread', id)
  const onDelete = id => $store.dispatch('$_assistant/deleteThread', id)

  return { threads, threadId, query, sort, sortOptions, list, onNew, onOpen, onDelete }
}

// @vue/component
export default {
  name: 'the-threads',
  setup
}
</script>

<style lang="scss">
.the-threads {
  max-height: calc(100vh - 16rem);
  overflow-y: auto;
}
.the-threads-card {
  .the-threads-new {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 2.25rem;
    height: 2.25rem;
    padding: 0;
    color: $gray-800;
    background-color: $white;
    border: 1px solid $gray-300;
    border-radius: .55rem;
    &:hover, &:focus { color: $primary; background-color: lighten($primary, 46%); }
  }
  .the-threads-filters {
    .form-control, .custom-select {
      background-color: $gray-100;
      border-color: transparent;
      border-radius: .5rem;
      &:focus { background-color: $white; border-color: lighten($primary, 25%); }
    }
  }
  .the-thread {
    border-left: 3px solid transparent;
    .the-thread-title { font-size: .875rem; color: $gray-900; }
    .the-thread-delete {
      color: $gray-500;
      opacity: 0;
      transition: opacity .15s;
      &:hover, &:focus { color: $danger; opacity: 1; }
    }
    &:hover, &:focus-within {
      background-color: $gray-100;
      .the-thread-delete { opacity: 1; }
    }
    &.is-active {
      background-color: lighten($primary, 46%);
      border-left-color: $primary;
      .the-thread-delete { opacity: 1; }
    }
  }
}
</style>
