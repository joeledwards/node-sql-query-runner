_ = require 'lodash'
Q = require 'q'
FS = require 'fs'
pg = require 'pg'
mysql = require 'mysql'
program = require 'commander'
durations = require 'durations'

# Read the SQL queries from the file
readQueriesFile = (file, separator=';') ->
  deferred = Q.defer()
  if not file?
    deferred.resolve []
  else
    FS.readFile file, {encoding: 'utf8'}, (error, contents) ->
      if error
        deferred.reject error
      else
        try
          queries = _(contents.split(separator))
          .filter (query) ->
            if query?
              true
            else
              false
          .map (query) ->
            _.trim query
          .filter (query) ->
            query.length > 0
          .value()
          console.log "queries: #{queries}"
          deferred.resolve queries
        catch error
          deferred.reject error
  deferred.promise

mysqlConnect = (mysqlConfig, config) ->
  deferred = Q.defer()
  console.log "connecting to MySQL..."
  connectWatch = durations.stopwatch().start()
  connection = mysql.mysql.createConnection mysqlConfig
  connection.connect (error) ->
    if error
      console.log "Error connecting to MySQL:", error, "\nStack:\n", error.stack
      deferred.reject error
    else
      console.log "Connected." if not config.quiet
      context =
        client: client
        done: (callack) ->
          connection.end () ->
            console.log "Disconnected." if disconnected
            callback() if callback
      deferred.resolve context
  deferred.promise

# Connect to the database at the specified URI 
pgConnect = (uri, config) ->
  deferred = Q.defer()
  console.log "connecting to PostgreSQL..."
  connectWatch = durations.stopwatch().start()
  pg.connect uri, (error, client, done) ->
    connectWatch.stop()
    if error
      console.log "Error connecting to PostgreSQL:", error, "\nStack:\n", error.stack
      deferred.reject error
    else
      console.log "Connected." if not config.quiet
      context =
        client: client
        done: (error) ->
          done(error)
          client.end()
      deferred.resolve context
  deferred.promise

# Runs individual queries, logging the query and its results to the console
runQuery = (client, queries, schema) ->
  deferred = Q.defer()
  if _(queries).size() > 0
    query = _(queries).first()
    console.log "\nRunning Query '#{query}'\n"
    client.query query, (error, results) ->
      if error?
        deferred.reject error
      else
        rows = if schema == 'mysql' then results else results.rows
        console.log "Result:\n", results.rows
        runQuery client, _(queries).rest(), schema
        .then -> deferred.resolve 0
  else
    console.log "No queries remaining."
    deferred.resolve 0
  return deferred.promise

# Runs the queries against MySQL
runMysqlQueries = (config, queries) ->
  myCfg =
    host: config.host
    port: config.port
    user: config.user
    password: config.password
    database: config.database
  console.log "Connecting to database:\n'#{JSON.stringify(myCfg)}'"

  mysqlConnect myCfg, config
  .then (context) ->
    context.watch = durations.stopwatch().start()
    console.log "Ready to query MySQL."
    runQuery context.client, queries
    .then ->
      context.watch.stop()
      console.log "Wrapping up connection. All queries took #{context.watch}"
    .finally -> context.done()
  .catch (error) ->
    console.log "Error running queries: #{error}\nStack:\n#{error.stack}"

# Runs the queries against PostgreSQL
runPgQueries = (config, queries) ->
  uri = "postgres://#{config.user}:#{config.password}@#{config.host}:#{config.port}/#{config.database}"
  console.log "Connecting to URI '#{uri}'"

  pgConnect uri, config
  .then (context) ->
    context.watch = durations.stopwatch().start()
    console.log "Ready to query PostgreSQL."
    runQuery context.client, queries
    .then ->
      context.watch.stop()
      console.log "Wrapping up connection. All queries took #{context.watch}"
    .finally -> context.done()
  .catch (error) ->
    console.log "Error running queries: #{error}\nStack:\n#{error.stack}"

runQueries = (config, queries) ->
  switch config.schema
    when 'postgres' then runPgQueries config, queries
    when 'mysql' then runMysqlQueries config, queries
    else console.error "Invalid schema. Valid values are 'postgres' and 'mysql'"

# Script was run directly
runScript = ->
  program
    .usage('[options] <query_file>')
    .option '-s, --schema <schema>', 'schema for the connection can be "postgres" or "mysql" (default is postgres)'
    .option '-D, --database <database>', 'database (default is postgres)'
    .option '-h, --host <host>', "the Postgres server'shostname (default is localhost)"
    .option '-p, --port <port>', "the Postgres server's port (default is 5432)", parseInt
    .option '-P, --password <password>', 'user password (default is empty)'
    .option '-q, --quiet', 'Silence non-error output (default is false)'
    .option '-u, --username <username>', 'user name (default is postgres)'
    .parse(process.argv)

  queriesFile = _(program.args).first()

  config =
    schema: program.schema ? 'postgres'
    host: program.host ? 'localhost'
    port: program.port ? 5432
    user: program.username ? 'postgres'
    password: program.password ? 'postgres'
    database: program.database ? 'postgres'
    quiet: program.quiet ? false
  
  readQueriesFile queriesFile
  .then (queries) ->
    runQueries config, queries
  .catch (error) ->
    console.log "Error reading queries from file '#{queriesFile}' : #{error}\nStack:\n#{error.stack}"

# Module
module.exports =
  runQueries: runQueries
  run: runScript

# If run directly
if require.main == module
  runScript()

