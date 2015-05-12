_ = require 'lodash'
Q = require 'q'
FS = require 'fs'
pg = require 'pg'
program = require 'commander'
durations = require 'durations'

# Read the SQL queries from the file
readQueriesFile = (file, separator=';') ->
  deferred = Q.defer()
  if not file?
    deferred.resolve {}
  else
    FS.readFile file, {encoding: 'utf8'}, (error, contents) ->
      if error
        deferred.reject error
      else
        try
          queries = _(contents.split(separator))
          .map (query) ->
            _.trim query
          .filter (query) ->
            query.length > 0
          .value()
          deferred.resolve queries
        catch error
          deferred.reject error
  deferred.promise

# Connect to the database at the specified URI 
pgConnect = (uri) ->
  deferred = Q.defer()
  console.log "connecting..."
  connectWatch = durations.stopwatch().start()
  pg.connect uri, (error, client, done) ->
    connectWatch.stop()
    if error
      console.log "[#{error}] connect timeout. Time elapsed: #{connectWatch}"
      deferred.reject error
    else
      console.log "Connected."
      context =
        client : client
        done : (error) ->
          done(error)
      deferred.resolve context
  deferred.promise

# Runs individual queries, logging the query and its results to the console
runQuery = (client, queries) ->
  if queries.length < 1
    console.log "No more queries."
    deferred = Q.defer()
    deferred.resolve 0
    return deferred.promise
  else
    query = _(queries).first()
    console.log "\nRunning Query '#{query}'\n"
    return client.query query
    .then (result) ->
      console.log "Result:\n", result
      runQuery client, _(queries).rest()

# Runs the queries
runQueries = (config, queries) ->
  uri = "postgres://#{config.username}:#{config.password}@#{config.host}:#{config.port}/#{config.database}"
  console.log "Connecting to URI '#{uri}'"
  pgConnect uri
  .then (context) ->
    console.log "Ready to query."
    runQuery context.client, queries
    .then ->
      return context
  .then (context) ->
    context.done()
  .catch (error) ->
    console.log "Error running queries: #{error}\nStack:\n#{error.stack}"

# Script was run directly
runScript = ->
  program
    .usage('[options] <query_file>')
    .option '-D, --database <db_name>', 'Postgres database (default is postgres)'
    .option '-h, --host <hostname>', 'Postgres host (default is localhost)'
    .option '-p, --port <port>', 'Postgres port (default is 5432)', parseInt
    .option '-P, --password <password>', 'Postgres user password (default is empty)'
    .option '-q, --quiet', 'Silence non-error output (default is false)'
    .option '-u, --username <username>', 'Posgres user name (default is postgres)'
    .parse(process.argv)

  queriesFile = _(program.args).first()

  config =
    host: program.host ? 'localhost'
    port: program.port ? 5432
    username: program.username ? 'postgres'
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
  run: runQueries

# If run directly
if require.main == module
  runScript()

