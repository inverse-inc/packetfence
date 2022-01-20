const db = require('node-persist')
const express = require('express')
const api = express()

const logRequest = (req, res, next) => {
  const { body, cookies, headers, hostname, ip, method, originalUrl, params, path, protocol, query, secure, subdomains, xhr } = req
  console.debug({ body, cookies, headers, hostname, ip, method, originalUrl, params, path, protocol, query, secure, subdomains, xhr })
  next()
}

api.get('/history', logRequest, async (req, res) => {
  Promise.resolve(db.init()).then(() => {
    db.getItem('history').then(history => {
      res.send(JSON.stringify(history, null, 2))
    })
  })
})

api.delete('/history', logRequest, async (req, res) => {
  Promise.resolve(db.init()).then(() => {
    db.setItem('history', []).then(() => {
      res.send(JSON.stringify([], null, 2))
    })
  })
})

module.exports = api