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
  connection = mysql.createConnection mysqlConfig
  connection.connect (error) ->
    if error
      console.log "Error connecting to MySQL:", error, "\nStack:\n", error.stack
      deferred.reject error
    else
      console.log "Connected." if not config.quiet
      context =
        client: connection
        done: (callback) ->
          connection.end () ->
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
runQuery = (client, queries, scheme) ->
  deferred = Q.defer()
  if _(queries).size() > 0
    query = _(queries).first()
    console.log "\nRunning Query '#{query}'\n"
    client.query query, (error, results) ->
      if error?
        deferred.reject error
      else
        rows = if scheme == 'mysql' then results else results.rows
        console.log "Result:\n", results.rows
        runQuery client, _.tail(queries), scheme
        .then -> deferred.resolve 0
  else
    console.log "No queries remaining."
    deferred.resolve 0
  return deferred.promise

# Runs the queries against MySQL
runMysqlQueries = (config, queries) ->
  # Extract only those fields which are of interest to MySQL
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
  {user, password, host, port, database} = config
  uri = "postgres://#{user}:#{password}@#{host}:#{port}/#{database}"
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

runQueries = (partialConfig, queries) ->
  config =
    scheme: partialConfig.scheme ? 'postgres'
    host: partialConfig.host ? 'localhost'
    port: partialConfig.port ? 5432
    user: partialConfig.username ? 'postgres'
    password: partialConfig.password ? 'postgres'
    database: partialConfig.database ? 'postgres'
    quiet: partialConfig.quiet ? false

  switch config.scheme
    when 'postgres' then runPgQueries config, queries
    when 'mysql' then runMysqlQueries config, queries
    else console.error "Invalid scheme. Valid values are 'postgres' and 'mysql'"

# Script was run directly
runScript = ->
  program
    .usage('[options] <query_file>')
    .option '-s, --scheme <scheme>', 'scheme for the connection can be "postgres" or "mysql" (default is "postgres")'
    .option '-D, --database <database>', 'database (default is "postgres")'
    .option '-h, --host <host>', 'the Postgres server\'s hostname (default is "localhost")'
    .option '-p, --port <port>', "the Postgres server's port (default is 5432)", parseInt
    .option '-P, --password <password>', 'user password (default is "")'
    .option '-q, --quiet', 'Silence non-error output (default is false)'
    .option '-u, --username <username>', 'user name (default is "postgres")'
    .parse(process.argv)

  queriesFile = _(program.args).first()

  partialConfig = 
    scheme: program.scheme
    host: program.host
    port: program.port
    user: program.username
    password: program.password
    database: program.database
    quiet: program.quiet
  
  readQueriesFile queriesFile
  .then (queries) ->
    runQueries partialConfig, queries
  .catch (error) ->
    console.log "Error reading queries from file '#{queriesFile}' : #{error}\nStack:\n#{error.stack}"

# Module
module.exports =
  runQueries: runQueries
  run: runScript

# If run directly
if require.main == module
  runScript()
