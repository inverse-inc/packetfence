<!-- # Vue.js-based pfappserver -->

## Introduction

* [Vue.js official guide](https://vuejs.org/v2/guide/)
* [Bootstrap + Vue](https://bootstrap-vue.js.org/)
* [ECMAScript 2015 (ES6) syntax](https://babeljs.io/learn-es2015/)
* [npm](https://www.npmjs.com/) -- package manager
* [webpack](https://webpack.js.org/) -- task runner
* [ESLint](https://eslint.org/) -- code linter and style checker
* [JavaScript Standard Style](https://github.com/standard/standard/blob/master/docs/RULES-en.md) -- code style
* `.editorconfig` -- code editor formatting/style

## Getting started

Setup is based on the official [boilerplate webpack template](http://vuejs-templates.github.io/webpack/).

```
npm install
npm run build
```

CSP must be disabled.

Make sure the following services are running:

* packetfence-netdata
* packetfence-pfperl-api
* packetfence-api-frontend
* packetfence-httpd.admin

Since this is a SPA (Single-Page Application), it is currently accessible from `https://<hostname>:1443/admin/alt`.

## Vue.js libraries

* [Vuex](https://vuex.vuejs.org/) -- state management
* [vue-router](https://router.vuejs.org/) -- official router
* [vue-i18n](https://kazupon.github.io/vue-i18n/) -- internationalization
* [messageformat](https://messageformat.github.io/messageformat/) -- internationalization formatting
* [vue-browser-acl](https://github.com/mblarsen/vue-browser-acl) -- ACLs
* [axios](https://github.com/axios/axios) -- http client
* [vuelidate](https://vuelidate.netlify.com/) -- form validation
* [vue-awesome](https://justineo.github.io/vue-awesome/demo/) -- font awesome component (svg)
* [vue2vis](https://github.com/alexcode/vue2vis/) -- VueJS to Vis
 * [vis](http://visjs.org/) -- Vis
* [vue-timeago](https://github.com/egoist/vue-timeago) -- show relative time
* [Plotly](https://plot.ly/javascript/reference/) -- svg charts
* [date-fns](https://date-fns.org/docs/Getting-Started) -- datetime utils
* [vue-flatpickr-component](https://github.com/ankurk91/vue-flatpickr-component) -- datetime picker
* [papaparse](https://www.papaparse.com/) -- parse CSV
* [uuid](https://www.npmjs.com/package/uuid) -- RFC4122 UUIDs
* [vue-multiselect](https://vue-multiselect.js.org/) -- multi-select/chosen component
* [vuedraggable](https://github.com/SortableJS/Vue.Draggable) -- draggable component
* [vue-scrollto](https://www.npmjs.com/package/vue-scrollto) -- animated scrolling
* [vue2-ace-editor](https://github.com/chairuosen/vue2-ace-editor) -- packaging of ace
 * [ace](https://ace.c9.io/)
* [d3-force](https://github.com/d3/d3-force) -- d3 force directed graphs

## Files Structure

```
├── index.html           # root template to generate `../admin/v-index.tt`
├── main.js
├── App.vue
├── components           # shared components
│   └── ...
├── views
│   ├── Login            # login page
|   |   ├── _api         # abstractions for making API requests
|   |   ├── _router      # routes definition for this view
|   |   ├── _store       # state management, API consumer
|   |   └── index.vue
|   └── ...
├── globals              # common constants
│   └── ...
├── router
│   └── ...
├── store
│   └── ...
├── utils
|   ├── api.js           # axios instance for unified API
│   ├── charts.js        # axios instance for netdata API
│   └── ...
└── styles               # imports and modifications of the official Bootstrap Sass
│   └── ...
```

## Cheatsheet

### Localization

To set the content of a component to a localized string:

```html
<b-button v-t="'Save'"></b-button>
```

To localize a property:

```html
<b-tab :title="$t('Profile')"></b-tab>
```

### User Access Control

Test a rule on a component:

```html
v-can:read="'auditing'"
```

Test on collection of subjects:

```html
v-can:access.some="[['reports', 'services']]"
v-can:access.every="[['reports', 'services']]"
```

The actions use dashes, the subjects use underscores:

```html
v-can:create-overwrite="'connection_profiles'"
```
