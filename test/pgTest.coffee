assert = require 'assert'
durations = require 'durations'
waitForPg = require '../src/index.coffee'

describe "sql-query-runner", ->
    it "should run a list of queries", (done) ->
        watch = durations.stopwatch().start()

        # TODO: test wait for connection


