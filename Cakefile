fs      = require 'fs'
jasmine = require 'jasmine-node'
config  = require './lib/config'

# You can override the configured defaults for port and host with flags.
option '-p', "--port [#{config.port}]", 'port the server runs on'
option '-h', "--host [#{config.host}]", 'base server name'
option '-s', "--secret [#{config.secret}]", 'session secret'

task 'runserver', 'Run the server, watching for changes.', (options) ->
  server = require './lib/server'
  server.start
    host: options.host or config.host
    port: options.port or config.port
    secret: options.secret or config.secret
    dbhost: config.dbhost
    dbport: config.dbport
    dbname: config.dbname

task 'test', 'Run tests', (options) ->
  jasmine.executeSpecsInFolder(
    specFolder=__dirname + '/spec',
    onComplete= ((runner, log) ->
      if runner.results().failedCount == 0
        process.exit 0
      else
        process.exit 1
    ),
    isVerbose=true,
    showColors=true,
    teamcity=false,
    useRequireJs=false,
    regExpSpec=/^.*spec\.(js|coffee)$/i,
    junitreport=false,
  )
