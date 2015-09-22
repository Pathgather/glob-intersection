path = require("path")
Jasmine = require('jasmine')

jasmine = new Jasmine(
  projectBaseDir: path.resolve()
  captureExceptions: true)

process.on "uncaughtException", (err) ->
  if jasmine.env
    jasmine.env.fail(err)
  else
    throw err

jasmine.loadConfigFile('spec/support/jasmine.json')
jasmine.execute()
