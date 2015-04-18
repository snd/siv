mesa = require 'mesa'
moment = require 'moment'
qs = require 'qs'

siv = require '../src/siv'

userTable = mesa.table('user')
error = new siv.Error {error: 'i am an error'}

module.exports =

  'readme example': (test) ->
    querystring = [
      'limit=10',
      'offset=20',
      'order=name',
      'asc=true',
      'where[is_active]=true',
      'where[email][ends]=gmail.com',
      'where[email][notcontains]=fake',
      'where[id][notin][]=100',
      'where[id][notin][]=200',
      'where[id][lt]=1000',
    ].join('&')

    query = qs.parse(querystring)
    test.deepEqual query,
      limit: '10'
      offset: '20'
      order: 'name'
      asc: 'true'
      where:
        is_active: 'true'
        email:
          ends: 'gmail.com'
          notcontains: 'fake'
        id:
          notin: ['100', '200']
          lt: '1000'

    sieved = mesa.table('user')
    sieved = siv.limit(sieved, query)
    sieved = siv.offset(sieved, query)
    sieved = siv.order(sieved, query, {allow: ['name']})
    sieved = siv.boolean(sieved, query, 'is_active')
    sieved = siv.string(sieved, query, 'email')
    sieved = siv.integer(sieved, query, 'id')

    test.ok not siv.isError sieved
    test.equal sieved.sql(), [
      'SELECT * FROM "user"'
      'WHERE ("is_active" = ?)'
      'AND email ILIKE \'%\' || ?'
      'AND email NOT ILIKE \'%\' || ? || \'%\''
      'AND ("id" NOT IN (?, ?))'
      'AND ("id" < ?)'
      'ORDER BY name ASC'
      'LIMIT ?'
      'OFFSET ?'
    ].join(' ')

    test.deepEqual sieved.params(),
      [true, 'gmail.com', 'fake', 100, 200, 1000, 10, 20]

    test.done()

  'limit':

    'ignore if not set': (test) ->
      sieved = siv.limit userTable, qs.parse 'foo=10'
      test.equal sieved, userTable
      test.equal sieved.sql(), 'SELECT * FROM "user"'
      test.deepEqual sieved.params(), []
      test.done()

    'set': (test) ->
      sieved = siv.limit userTable, qs.parse 'limit=10'
      test.equal sieved.sql(), 'SELECT * FROM "user" LIMIT ?'
      test.deepEqual sieved.params(), [10]
      test.done()

    'error create': (test) ->
      sieved = siv.limit userTable, qs.parse 'limit=a'
      test.ok siv.isError sieved
      test.deepEqual sieved.json,
        limit: 'must be an integer'
      test.done()

    'error passthrough when set': (test) ->
      sieved = siv.limit error, qs.parse 'limit=10'
      test.ok siv.isError sieved
      test.deepEqual sieved.json,
        error: 'i am an error'
      test.done()

    'error extend': (test) ->
      sieved = siv.limit error, qs.parse 'limit=a'
      test.ok siv.isError sieved
      test.notEqual error, sieved
      test.deepEqual sieved.json,
        error: 'i am an error'
        limit: 'must be an integer'
      test.done()

  'offset':

    'ignore if not set': (test) ->
      sieved = siv.offset userTable, qs.parse 'foo=10'
      test.equal sieved, userTable
      test.equal sieved.sql(), 'SELECT * FROM "user"'
      test.deepEqual sieved.params(), []
      test.done()

    'set': (test) ->
      sieved = siv.offset userTable, qs.parse 'offset=10'
      test.equal sieved.sql(), 'SELECT * FROM "user" OFFSET ?'
      test.deepEqual sieved.params(), [10]
      test.done()

    'error create': (test) ->
      sieved = siv.offset userTable, qs.parse 'offset=a'
      test.ok siv.isError sieved
      test.deepEqual sieved.json,
        offset: 'must be an integer'
      test.done()

    'error passthrough when set': (test) ->
      sieved = siv.offset error, qs.parse 'offset=10'
      test.ok siv.isError sieved
      test.deepEqual sieved.json,
        error: 'i am an error'
      test.done()

    'error extend': (test) ->
      sieved = siv.offset error, qs.parse 'offset=a'
      test.ok siv.isError sieved
      test.notEqual error, sieved
      test.deepEqual sieved.json,
        error: 'i am an error'
        offset: 'must be an integer'
      test.done()

  'order':
    'throw when none allowed': (test) ->
      test.expect 2
      try
        siv.order userTable, {}
      catch e
        test.equal e.message, '`options.allow` must be an array with at least one element'
      try
        siv.order userTable, {}, {allow: []}
      catch e
        test.equal e.message, '`options.allow` must be an array with at least one element'
      test.done()

    'throw when only options.asc set': (test) ->
      try
        siv.order userTable, {},
          allow: ['id']
          asc: true
      catch e
        test.equal e.message, 'if `options.asc` is set then `options.order` must also be set'
        test.done()

    'ignored when no default and not set': (test) ->
      sieved = siv.order userTable, qs.parse('foo=10'),
        allow: ['id']
      test.equal sieved, userTable
      test.equal sieved.sql(), 'SELECT * FROM "user"'
      test.deepEqual sieved.params(), []
      test.done()

    'default order': (test) ->
      sieved = siv.order userTable, qs.parse('foo=10'),
        allow: ['id']
        order: 'created_at'
      test.equal sieved.sql(), 'SELECT * FROM "user" ORDER BY created_at ASC'
      test.deepEqual sieved.params(), []
      test.done()

    'default order and asc': (test) ->
      sieved = siv.order userTable, qs.parse('foo=10'),
        allow: ['id']
        order: 'created_at'
        asc: false
      test.equal sieved.sql(), 'SELECT * FROM "user" ORDER BY created_at DESC'
      test.deepEqual sieved.params(), []
      test.done()

    'error when blank query.order': (test) ->
      sieved = siv.order userTable, qs.parse('order='),
        allow: ['id']
        order: 'created_at'
        asc: false
      test.ok siv.isError sieved
      test.deepEqual sieved.json,
        order: 'must not be blank if set'
      test.done()

    'error when not allowed': (test) ->
      sieved = siv.order userTable, qs.parse('order=name'),
        allow: ['id']
        order: 'created_at'
        asc: false
      test.ok siv.isError sieved
      test.deepEqual sieved.json,
        order: 'ordering by this column is not allowed'
      test.done()

    'error when query.asc is not the string `true` or the string `false`': (test) ->
      sieved = siv.order userTable, qs.parse('asc=foo'),
        allow: ['id']
        order: 'created_at'
        asc: false
      test.ok siv.isError sieved
      test.deepEqual sieved.json,
        asc: 'must be either the string `true` or the string `false`'
      test.done()

    'error when no default and only asc': (test) ->
      sieved = siv.order userTable, qs.parse('asc=true'),
        allow: ['id']
      test.ok siv.isError sieved
      test.deepEqual sieved.json,
        asc: 'if `asc` is set then `order` must also be set'
      test.done()

    'error passthrough when ignored': (test) ->
      sieved = siv.order error, qs.parse('foo=true'),
        allow: ['id']
      test.ok siv.isError sieved
      test.deepEqual sieved.json,
        error: 'i am an error'
      test.done()

    'error passthrough when set': (test) ->
      sieved = siv.order error, qs.parse('order=id'),
        allow: ['name', 'id']
        order: 'name'
        asc: true
      test.ok siv.isError sieved
      test.deepEqual sieved.json,
        error: 'i am an error'
      test.done()

    'error extend': (test) ->
      sieved = siv.order error, qs.parse('order=name'),
        allow: ['id']
      test.ok siv.isError sieved
      test.deepEqual sieved.json,
        error: 'i am an error'
        order: 'ordering by this column is not allowed'
      test.done()

    'error extend twice': (test) ->
      sieved = siv.order error, qs.parse('order=name&asc=foo'),
        allow: ['id']
      test.ok siv.isError sieved
      test.deepEqual sieved.json,
        error: 'i am an error'
        order: 'ordering by this column is not allowed'
        asc: 'must be either the string `true` or the string `false`'
      test.done()

    'set order': (test) ->
      sieved = siv.order userTable, qs.parse('order=id'),
        allow: ['name', 'id']
        order: 'name'
        asc: true
      test.equal sieved.sql(), 'SELECT * FROM "user" ORDER BY id ASC'
      test.deepEqual sieved.params(), []
      test.done()

    'set order and asc': (test) ->
      sieved = siv.order userTable, qs.parse('order=id&asc=false'),
        allow: ['name', 'id']
        order: 'name'
        asc: true
      test.equal sieved.sql(), 'SELECT * FROM "user" ORDER BY id DESC'
      test.deepEqual sieved.params(), []
      test.done()

  'nullable':

    'ignore if not set': (test) ->
      sieved = siv.nullable userTable, {foo: '10'}, 'name'
      test.equal sieved.sql(), 'SELECT * FROM "user"'
      test.deepEqual sieved.params(), []
      test.done()

    'error when not the string `true` or the string `false`': (test) ->
      sieved = siv.nullable userTable, {where: {name: {null: 'foo'}}}, 'name'
      test.ok siv.isError sieved
      test.deepEqual sieved.json,
        where: {name: {null: 'must be either the string `true` or the string `false`'}}
      test.done()

    'error passthrough when ignored': (test) ->
      sieved = siv.nullable error, {foo: 'true'}, 'name'
      test.ok siv.isError sieved
      test.deepEqual sieved.json,
        error: 'i am an error'
      test.done()

    'error passthrough when set': (test) ->
      sieved = siv.nullable error, {where: {name: {null: 'true'}}}, 'name'
      test.ok siv.isError sieved
      test.deepEqual sieved.json,
        error: 'i am an error'
      test.done()

    'error extend': (test) ->
      sieved = siv.nullable error, {where: {name: {null: 'foo'}}}, 'name'
      test.ok siv.isError sieved
      test.deepEqual sieved.json,
        where: {name: {null: 'must be either the string `true` or the string `false`'}}
        error: 'i am an error'
      test.done()

    'set null': (test) ->
      sieved = siv.nullable userTable, {where: {name: {null: 'true'}}}, 'name'
      test.equal sieved.sql(), 'SELECT * FROM "user" WHERE "name" IS NULL'
      test.done()

    'set not null': (test) ->
      sieved = siv.nullable userTable, {where: {name: {null: 'false'}}}, 'name'
      test.equal sieved.sql(), 'SELECT * FROM "user" WHERE "name" IS NOT NULL'
      test.done()

  'integer':

    'ignore if not set': (test) ->
      sieved = siv.integer userTable, {foo: '10'}, 'id'
      test.equal sieved.sql(), 'SELECT * FROM "user"'
      test.deepEqual sieved.params(), []
      test.done()

    'error passthrough when ignored': (test) ->
      sieved = siv.integer error, {foo: 'true'}, 'id'
      test.ok siv.isError sieved
      test.deepEqual sieved.json,
        error: 'i am an error'
      test.done()

    'short form':

      'error passthrough when set': (test) ->
        sieved = siv.integer error, {where: {id: '10'}}, 'id'
        test.ok siv.isError sieved
        test.deepEqual sieved.json,
          error: 'i am an error'
        test.done()

      'error when not integer': (test) ->
        sieved = siv.integer userTable, {where: {id: 'foo'}}, 'id'
        test.ok siv.isError sieved
        test.deepEqual sieved.json,
          where: {id: 'must be parsable as an integer'}
        test.done()

      'error extend': (test) ->
        sieved = siv.integer error, {where: {id: 'foo'}}, 'id'
        test.ok siv.isError sieved
        test.deepEqual sieved.json,
          where: {id: 'must be parsable as an integer'}
          error: 'i am an error'
        test.done()

      'equals': (test) ->
        sieved = siv.integer userTable, {where: {id: '10'}}, 'id'
        test.equal sieved.sql(), 'SELECT * FROM "user" WHERE "id" = ?'
        test.deepEqual sieved.params(), [10]
        test.done()

    'long form':

      'error passthrough when set': (test) ->
        sieved = siv.integer error, {where: {id: {equals: '10'}}}, 'id'
        test.ok siv.isError sieved
        test.deepEqual sieved.json,
          error: 'i am an error'
        test.done()

      'create error when not integer': (test) ->
        sieved = siv.integer userTable, {where: {id: {equals: 'foo'}}}, 'id'
        test.ok siv.isError sieved
        test.deepEqual sieved.json,
          where: {id: {equals: 'must be parsable as an integer'}}
        test.done()

      'error extend': (test) ->
        sieved = siv.integer error, {where: {id: {equals: 'foo'}}}, 'id'
        test.ok siv.isError sieved
        test.deepEqual sieved.json,
          where: {id: {equals: 'must be parsable as an integer'}}
          error: 'i am an error'
        test.done()

      'equals': (test) ->
        sieved = siv.integer userTable, {where: {id: {equals: '10'}}}, 'id'
        test.equal sieved.sql(), 'SELECT * FROM "user" WHERE "id" = ?'
        test.deepEqual sieved.params(), [10]
        test.done()

      'notequals': (test) ->
        sieved = siv.integer userTable, {where: {id: {notequals: '10'}}}, 'id'
        test.equal sieved.sql(), 'SELECT * FROM "user" WHERE "id" != ?'
        test.deepEqual sieved.params(), [10]
        test.done()

      'lt': (test) ->
        sieved = siv.integer userTable, {where: {id: {lt: '10'}}}, 'id'
        test.equal sieved.sql(), 'SELECT * FROM "user" WHERE "id" < ?'
        test.deepEqual sieved.params(), [10]
        test.done()

      'lte': (test) ->
        sieved = siv.integer userTable, {where: {id: {lte: '1000'}}}, 'id'
        test.equal sieved.sql(), 'SELECT * FROM "user" WHERE "id" <= ?'
        test.deepEqual sieved.params(), [1000]
        test.done()

      'gt': (test) ->
        sieved = siv.integer userTable, {where: {id: {gt: '439'}}}, 'id'
        test.equal sieved.sql(), 'SELECT * FROM "user" WHERE "id" > ?'
        test.deepEqual sieved.params(), [439]
        test.done()

      'gte': (test) ->
        sieved = siv.integer userTable, {where: {id: {gte: '9383498'}}}, 'id'
        test.equal sieved.sql(), 'SELECT * FROM "user" WHERE "id" >= ?'
        test.deepEqual sieved.params(), [9383498]
        test.done()

      'in & notin':

        'create error when not array': (test) ->
          sieved = siv.integer userTable, {where: {id: {in: 'foo'}}}, 'id'
          test.ok siv.isError sieved
          test.deepEqual sieved.json,
            where: {id: {in: 'must be an array'}}
          test.done()

        'create error when empty array': (test) ->
          sieved = siv.integer userTable, {where: {id: {in: []}}}, 'id'
          test.ok siv.isError sieved
          test.deepEqual sieved.json,
            where: {id: {in: 'must not be empty'}}
          test.done()

        'create error when items not parsable': (test) ->
          sieved = siv.integer userTable, {where: {id: {in: ['foo', '1', '2', 'bar', '3']}}}, 'id'
          test.ok siv.isError sieved
          test.deepEqual sieved.json,
            where:
              id:
                in:
                  0: 'must be parsable as an integer'
                  3: 'must be parsable as an integer'
          test.done()

        'error extend': (test) ->
          sieved = siv.integer error, {where: {id: {in: 'foo'}}}, 'id'
          test.ok siv.isError sieved
          test.deepEqual sieved.json,
            where: {id: {in: 'must be an array'}}
            error: 'i am an error'
          test.done()

        'in': (test) ->
          sieved = siv.integer userTable, {where: {id: {in: [1, 2, 3]}}}, 'id'
          test.equal sieved.sql(), 'SELECT * FROM "user" WHERE "id" IN (?, ?, ?)'
          test.deepEqual sieved.params(), [1, 2, 3]
          test.done()

        'notin': (test) ->
          sieved = siv.integer userTable, {where: {id: {notin: [1, 2, 3]}}}, 'id'
          test.equal sieved.sql(), 'SELECT * FROM "user" WHERE "id" NOT IN (?, ?, ?)'
          test.deepEqual sieved.params(), [1, 2, 3]
          test.done()

  'string':

    'ignore if not set': (test) ->
      sieved = siv.string userTable, {foo: '10'}, 'id'
      test.equal sieved.sql(), 'SELECT * FROM "user"'
      test.deepEqual sieved.params(), []
      test.done()

    'error passthrough when ignored': (test) ->
      sieved = siv.string error, {foo: 'true'}, 'id'
      test.ok siv.isError sieved
      test.deepEqual sieved.json,
        error: 'i am an error'
      test.done()

    'short form':

      'error passthrough when set': (test) ->
        sieved = siv.string error, {where: {name: 'ann'}}, 'name'
        test.ok siv.isError sieved
        test.deepEqual sieved.json,
          error: 'i am an error'
        test.done()

      'equals': (test) ->
        sieved = siv.string userTable, {where: {name: 'ann'}}, 'name'
        test.equal sieved.sql(), 'SELECT * FROM "user" WHERE "name" = ?'
        test.deepEqual sieved.params(), ['ann']
        test.done()

    'long form':

      'error passthrough when set': (test) ->
        sieved = siv.string error, {where: {name: {equals: 'ann'}}}, 'name'
        test.ok siv.isError sieved
        test.deepEqual sieved.json,
          error: 'i am an error'
        test.done()

      'equals': (test) ->
        sieved = siv.string userTable, {where: {name: {equals: 'ann'}}}, 'name'
        test.equal sieved.sql(), 'SELECT * FROM "user" WHERE name = ?'
        test.deepEqual sieved.params(), ['ann']
        test.done()

      'notequals': (test) ->
        sieved = siv.string userTable, {where: {name: {notequals: 'ann'}}}, 'name'
        test.equal sieved.sql(), 'SELECT * FROM "user" WHERE name != ?'
        test.deepEqual sieved.params(), ['ann']
        test.done()

      'contains': (test) ->
        sieved = siv.string userTable, {where: {name: {contains: 'ann'}}}, 'name'
        test.equal sieved.sql(), "SELECT * FROM \"user\" WHERE name ILIKE '%' || ? || '%'"
        test.deepEqual sieved.params(), ['ann']
        test.done()

      'notcontains': (test) ->
        sieved = siv.string userTable, {where: {name: {notcontains: 'ann'}}}, 'name'
        test.equal sieved.sql(), "SELECT * FROM \"user\" WHERE name NOT ILIKE '%' || ? || '%'"
        test.deepEqual sieved.params(), ['ann']
        test.done()

      'begins': (test) ->
        sieved = siv.string userTable, {where: {name: {begins: 'ann'}}}, 'name'
        test.equal sieved.sql(), "SELECT * FROM \"user\" WHERE name ILIKE ? || '%'"
        test.deepEqual sieved.params(), ['ann']
        test.done()

      'notbegins': (test) ->
        sieved = siv.string userTable, {where: {name: {notbegins: 'ann'}}}, 'name'
        test.equal sieved.sql(), "SELECT * FROM \"user\" WHERE name NOT ILIKE ? || '%'"
        test.deepEqual sieved.params(), ['ann']
        test.done()

      'ends': (test) ->
        sieved = siv.string userTable, {where: {name: {ends: 'ann'}}}, 'name'
        test.equal sieved.sql(), "SELECT * FROM \"user\" WHERE name ILIKE '%' || ?"
        test.deepEqual sieved.params(), ['ann']
        test.done()

      'notends': (test) ->
        sieved = siv.string userTable, {where: {name: {notends: 'ann'}}}, 'name'
        test.equal sieved.sql(), "SELECT * FROM \"user\" WHERE name NOT ILIKE '%' || ?"
        test.deepEqual sieved.params(), ['ann']
        test.done()

      'in & notin':

        'create error when not array': (test) ->
          sieved = siv.string userTable, {where: {name: {in: 'foo'}}}, 'name'
          test.ok siv.isError sieved
          test.deepEqual sieved.json,
            where: {name: {in: 'must be an array'}}
          test.done()

        'create error when empty array': (test) ->
          sieved = siv.string userTable, {where: {name: {in: []}}}, 'name'
          test.ok siv.isError sieved
          test.deepEqual sieved.json,
            where: {name: {in: 'must not be empty'}}
          test.done()

        'error extend': (test) ->
          sieved = siv.string error, {where: {name: {in: 'foo'}}}, 'name'
          test.ok siv.isError sieved
          test.deepEqual sieved.json,
            where: {name: {in: 'must be an array'}}
            error: 'i am an error'
          test.done()

        'in': (test) ->
          sieved = siv.string userTable, {where: {name: {in: ['a', 'b', 'c']}}}, 'name'
          test.equal sieved.sql(), 'SELECT * FROM "user" WHERE "name" IN (?, ?, ?)'
          test.deepEqual sieved.params(), ['a', 'b', 'c']
          test.done()

        'notin': (test) ->
          sieved = siv.string userTable, {where: {name: {notin: ['a', 'b', 'c']}}}, 'name'
          test.equal sieved.sql(), 'SELECT * FROM "user" WHERE "name" NOT IN (?, ?, ?)'
          test.deepEqual sieved.params(), ['a', 'b', 'c']
          test.done()

  'bool':

    'ignore if not set': (test) ->
      sieved = siv.boolean userTable, {foo: '10'}, 'active'
      test.equal sieved.sql(), 'SELECT * FROM "user"'
      test.deepEqual sieved.params(), []
      test.done()

    'error when not the string `true` or the string `false`': (test) ->
      sieved = siv.boolean userTable, {where: {active: 'foo'}}, 'active'
      test.ok siv.isError sieved
      test.deepEqual sieved.json,
        where: {active: 'must be either the string `true` or the string `false`'}
      test.done()

    'error passthrough when ignored': (test) ->
      sieved = siv.boolean error, {foo: 'true'}, 'active'
      test.ok siv.isError sieved
      test.deepEqual sieved.json,
        error: 'i am an error'
      test.done()

    'error passthrough when set': (test) ->
      sieved = siv.boolean error, {where: {active: 'true'}}, 'active'
      test.ok siv.isError sieved
      test.deepEqual sieved.json,
        error: 'i am an error'
      test.done()

    'error extend': (test) ->
      sieved = siv.boolean error, {where: {active: 'foo'}}, 'active'
      test.ok siv.isError sieved
      test.deepEqual sieved.json,
        where: {active: 'must be either the string `true` or the string `false`'}
        error: 'i am an error'
      test.done()

    'set true': (test) ->
      sieved = siv.boolean userTable, {where: {active: 'true'}}, 'active'
      test.equal sieved.sql(), 'SELECT * FROM "user" WHERE "active" = ?'
      test.deepEqual sieved.params(), [true]
      test.done()

    'set false': (test) ->
      sieved = siv.boolean userTable, {where: {active: 'false'}}, 'active'
      test.equal sieved.sql(), 'SELECT * FROM "user" WHERE "active" = ?'
      test.deepEqual sieved.params(), [false]
      test.done()

  'date':

    'ignore if not set': (test) ->
      sieved = siv.date userTable, {foo: '10'}, 'created'
      test.equal sieved.sql(), 'SELECT * FROM "user"'
      test.deepEqual sieved.params(), []
      test.done()

    'error when not parsable as a date': (test) ->
      sieved = siv.date userTable, {where: {created: 'foo'}}, 'created'
      test.ok siv.isError sieved
      test.deepEqual sieved.json,
        where: {created: 'cant parse a date from the string'}
      test.done()

    'error passthrough when ignored': (test) ->
      sieved = siv.date error, {foo: 'true'}, 'created'
      test.ok siv.isError sieved
      test.deepEqual sieved.json,
        error: 'i am an error'
      test.done()

    'error passthrough when set': (test) ->
      sieved = siv.date error, {where: {created: 'today'}}, 'created'
      test.ok siv.isError sieved
      test.deepEqual sieved.json,
        error: 'i am an error'
      test.done()

    # 'equals shorthand':

      # 'set':

        # 'yesterday': (test) ->
        #   sieved = siv.date userTable, {where: {created: 'yesterday'}}, 'created',
        #     moment('2015-04-15').toDate()
        #   test.equal sieved.sql(), 'SELECT * FROM "user" WHERE "created" = ?'
        #   params = sieved.params()
        #   test.equal params.length, 1
        #   console.log params
        #   test.ok moment(params[0]).isSame(moment('2015-04-14'))
        #   test.done()

#         'today': (test) ->
#           sieved = siv.date userTable, {where: {created: 'today'}}, 'created'
#           test.equal sieved.sql(), 'SELECT * FROM "user" WHERE "created" = ?'
#           params = sieved.params()
#           test.equal params.length, 1
#           console.log params
#           test.done()
#
#         'tomorrow': (test) ->
#           sieved = siv.date userTable, {where: {created: 'today'}}, 'created'
#           test.equal sieved.sql(), 'SELECT * FROM "user" WHERE "created" = ?'
#           params = sieved.params()
#           test.equal params.length, 1
#           console.log params
#           test.done()
#
#         '5 days ago': (test) ->
#           sieved = siv.date userTable, {where: {created: '5 days ago'}}, 'created'
#           test.equal sieved.sql(), 'SELECT * FROM "user" WHERE "created" = ?'
#           params = sieved.params()
#           test.equal params.length, 1
#           console.log params
#           test.done()

      # 'error extend': (test) ->
      #   sieved = siv.integer error, {where: {id: 'foo'}}, 'id'
      #   test.ok siv.isError sieved
      #   test.deepEqual sieved.json,
      #     where: {id: 'must be parsable as an integer'}
      #     error: 'i am an error'
      #   test.done()

  'all at once':

    'success': (test) ->
      test.done()

    'error': (test) ->
      # TODO produce all possible errors
      test.done()
