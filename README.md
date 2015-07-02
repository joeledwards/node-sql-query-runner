
SQL Query Runner
===========

Runs all files in the supplied file against a Postgres or MySQL database.


Installation
============

```bash
npm install --save sql-query-runner
```


Usage
=====

Run as a module within another script

```coffeescript
queryRunner = require 'sql-query-runner'
queries = ['SELECT 1', 'SELECT 2']
config =
  username: 'user'
  password: 'pass'

queryRunner.run(config, queries)
```


Run as a standalone script

```bash
sql-query-runnner --username=user --password=pass queries.sql
```


Build
=====

```bash
cake build
```

