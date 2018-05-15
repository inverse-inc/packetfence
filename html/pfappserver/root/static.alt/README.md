# Vue.js-based pfappserver

## Introduction

* [Bootstrap + Vue](https://bootstrap-vue.js.org/) 
* [ECMAScript 2015 (ES6) syntax](https://babeljs.io/learn-es2015/)
* [JavaScript Standard Style](https://github.com/standard/standard/blob/master/docs/RULES-en.md)

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

* [Vuex](https://vuex.vuejs.org/)
* [vue-router](https://router.vuejs.org/)
* [vue-i18n](https://kazupon.github.io/vue-i18n/)
* [vue-browser-acl](https://github.com/mblarsen/vue-browser-acl)
* [axios](https://github.com/axios/axios)
* [vue-awesome](https://justineo.github.io/vue-awesome/demo/)

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
```

The actions use dashes, the subjects use underscores:

```html
v-can:create-overwrite="'connection_profiles'"
```