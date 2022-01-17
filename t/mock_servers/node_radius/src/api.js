const db = require('node-persist')
const express = require('express')
const api = express()

api.get('/history', async (req, res) => {
  Promise.resolve(db.init()).then(() => {
    db.getItem('history').then(history => {
      res.send(JSON.stringify(history, null, 2))
    })
  })
})

module.exports = api