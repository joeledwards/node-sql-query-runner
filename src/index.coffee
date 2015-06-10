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
          client.end()
      deferred.resolve context
  deferred.promise

# Runs individual queries, logging the query and its results to the console
runQuery = (client, queries) ->
  deferred = Q.defer()
  if _(queries).size() > 0
    query = _(queries).first()
    console.log "\nRunning Query '#{query}'\n"
    client.query query, (error, results) ->
      if error?
        deferred.reject error
      else
        console.log "Result:\n", results.rows
        runQuery client, _(queries).rest()
        .then ->
          deferred.resolve 0
  else
    console.log "No queries remaining."
    deferred.resolve 0
  return deferred.promise

# Runs the queries
runQueries = (config, queries) ->
  uri = "postgres://#{config.username}:#{config.password}@#{config.host}:#{config.port}/#{config.database}"
  console.log "Connecting to URI '#{uri}'"

  pgConnect uri
  .then (context) ->
    context.watch = durations.stopwatch().start()
    console.log "Ready to query."
    runQuery context.client, queries
    .then ->
      return context
    .then (context) ->
      context.watch.stop()
      console.log "Wrapping up connection. All queries took #{context.watch}"
    .finally ->
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
  runQueries: runQueries
  run: runScript

# If run directly
if require.main == module
  runScript()

