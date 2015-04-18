((root, factory) ->
  # AMD
  if ('function' is typeof define) and define.amd?
    define(['chrono', 'lodash'], factory)
  # CommonJS
  else if exports?
    module.exports = factory(require('chrono-node'), require('lodash'))
  # no module system
  else
    root.siv = factory(root.chrono, root._)
)(this, (chrono, _) ->
  siv = {}

  siv.limit = (table, query) ->
    unless query.limit?
      return table

    parsed = parseInt query.limit, 10
    if isNaN parsed
      return new siv.Error {limit: 'must be an integer'}, table

    if siv.isError table
      return table

    table.limit(parsed)

  siv.offset = (table, query) ->
    unless query.offset?
      return table

    parsed = parseInt query.offset, 10
    if isNaN parsed
      return new siv.Error {offset: 'must be an integer'}, table

    if siv.isError table
      return table

    table.offset(parsed)

  siv.order = (table, query, options) ->
    unless 0 < options?.allow?.length
      throw new Error '`options.allow` must be an array with at least one element'

    if options.asc? and not options.order?
      throw new Error 'if `options.asc` is set then `options.order` must also be set'

    if siv.isError table
      error = table

    if query.order?
      if query.order is ''
        error = new siv.Error {order: 'must not be blank if set'}, error
      else unless (query.order in options.allow) or (query.order is options.default)
        error = new siv.Error {order: 'ordering by this column is not allowed'}, error
      else
        order = query.order
    else
      order = options.order

    if query.asc?
      if not order? and not error?
        # no default order. need order
        error = new siv.Error {asc: 'if `asc` is set then `order` must also be set'}, error
      else if query.asc is 'true'
        asc = true
      else if query.asc is 'false'
        asc = false
      else
        error = new siv.Error {asc: 'must be either the string `true` or the string `false`'}, error
    else
      if options.asc?
        asc = options.asc
      else
        asc = true

    if error?
      return error

    if order?
      return table.order(order + ' ' + (if asc then 'ASC' else 'DESC'))

    return table

  siv.nullable = (table, query, column) ->
    unless ('string' is typeof column) and (column isnt '')
      throw new Error 'column must be a non-blank string'

    value = query?.where?[column]
    unless value?.null?
      return table

    unless value.null in ['true', 'false']
      json = {where: {}}
      json.where[column] = {null: 'must be either the string `true` or the string `false`'}
      return new siv.Error json, table

    if siv.isError table
      return table

    condition = {}
    condition[column] = {$null: value.null is 'true'}
    return table.where(condition)

  siv.integer = (table, query, column) ->
    unless ('string' is typeof column) and (column isnt '')
      throw new Error 'column must be a non-blank string'

    value = query?.where?[column]
    unless value?
      return table

    if 'string' is typeof value
      parsed = parseInt value, 10
      if isNaN parsed
        json = {where: {}}
        json.where[column] = 'must be parsable as an integer'
        return new siv.Error json, table
      if siv.isError table
        return table
      condition = {}
      condition[column] = parsed
      return table.where(condition)

    # TODO
    # if Array.isArray value

    unless 'object' is typeof value
      return table

    if siv.isError table
      error = table

    t = table
    Object.keys(value).forEach (key) ->
      if key in ['in', 'notin']
        unless Array.isArray value[key]
          json = {where: {}}
          json.where[column] = {}
          json.where[column][key] = 'must be an array'
          error = new siv.Error json, error
          return
        unless value[key].length > 0
          json = {where: {}}
          json.where[column] = {}
          json.where[column][key] = 'must not be empty'
          error = new siv.Error json, error
          return
        integers = []
        _.forEach value[key], (item, index) ->
          parsed = parseInt item, 10
          if isNaN parsed
            json = {where: {}}
            json.where[column] = {}
            json.where[column][key] = {}
            json.where[column][key][index] = 'must be parsable as an integer'
            error = new siv.Error json, error
            return
          integers.push parsed
        if error?
          return
        condition = {}
        condition[column] = {}
        criterionKey = if key is 'in' then '$in' else '$nin'
        condition[column][criterionKey] = integers
        t = t.where(condition)
        return

      parsed = parseInt value[key], 10
      if isNaN parsed
        json = {where: {}}
        json.where[column] = {}
        json.where[column][key] = 'must be parsable as an integer'
        error = new siv.Error json, error

      if error?
        return

      switch key
        when 'equals'
          condition = {}
          condition[column] = parsed
          t = t.where(condition)
        when 'notequals'
          condition = {}
          condition[column] = {$ne: parsed}
          t = t.where(condition)
        when 'lt'
          condition = {}
          condition[column] = {$lt: parsed}
          t = t.where(condition)
        when 'lte'
          condition = {}
          condition[column] = {$lte: parsed}
          t = t.where(condition)
        when 'gt'
          condition = {}
          condition[column] = {$gt: parsed}
          t = t.where(condition)
        when 'gte'
          condition = {}
          condition[column] = {$gte: parsed}
          t = t.where(condition)

    if error?
      return error
    return t

  siv.string = (table, query, column) ->
    unless ('string' is typeof column) and (column isnt '')
      throw new Error 'column must be a non-blank string'

    value = query?.where?[column]
    unless value?
      return table

    if 'string' is typeof value
      condition = {}
      condition[column] = value
      if siv.isError table
        return table
      return table.where(condition)

    unless 'object' is typeof value
      return table

    if siv.isError table
      error = table

    t = table
    Object.keys(value).forEach (key) ->
      if key in ['in', 'notin']
        unless Array.isArray value[key]
          json = {where: {}}
          json.where[column] = {}
          json.where[column][key] = 'must be an array'
          error = new siv.Error json, error
          return
        unless value[key].length > 0
          json = {where: {}}
          json.where[column] = {}
          json.where[column][key] = 'must not be empty'
          error = new siv.Error json, error
          return
        if error?
          return
        condition = {}
        condition[column] = {}
        criterionKey = if key is 'in' then '$in' else '$nin'
        condition[column][criterionKey] = value[key]
        t = t.where(condition)
        return

      if error?
        return

      switch key
        when 'equals'
          t = t.where("#{column} = ?", value[key])
        when 'notequals'
          t = t.where("#{column} != ?", value[key])
        when 'contains'
          t = t.where("#{column} ILIKE '%' || ? || '%'", value[key])
        when 'notcontains'
          t = t.where("#{column} NOT ILIKE '%' || ? || '%'", value[key])
        when 'begins'
          t = t.where("#{column} ILIKE ? || '%'", value[key])
        when 'notbegins'
          t = t.where("#{column} NOT ILIKE ? || '%'", value[key])
        when 'ends'
          t = t.where("#{column} ILIKE '%' || ?", value[key])
        when 'notends'
          t = t.where("#{column} NOT ILIKE '%' || ?", value[key])

    if siv.isError error
      return error
    return t

  siv.boolean = (table, query, column) ->
    unless ('string' is typeof column) and (column isnt '')
      throw new Error 'column must be a non-blank string'

    value = query?.where?[column]
    unless value?
      return table

    unless 'string' is typeof value
      return table

    unless value in ['true', 'false']
      json = {where: {}}
      json.where[column] = 'must be either the string `true` or the string `false`'
      return new siv.Error json, table

    if siv.isError table
      return table

    condition = {}
    condition[column] = value is 'true'
    return table.where(condition)

  siv.date = (table, query, column, referenceDate) ->
    unless ('string' is typeof column) and (column isnt '')
      throw new Error 'column must be a non-blank string'
    unless referenceDate?
      referenceDate = new Date()

    value = query?.where?[column]
    unless value?
      return table

    if 'string' is typeof value
      results = chrono.parse value, referenceDate
      result = results[0]
      unless result?
        json = {where: {}}
        # TODO improve error message
        json.where[column] = 'cant parse a date from the string'
        return new siv.Error json, table

      if siv.isError table
        return table

      condition = {}
      unless result.end?
        condition[column] = result.start.date()
        return table.where(condition)

      condition[column] =
        gte: result.start.date()
        lte: result.end.date()
      return table.where(condition)

    unless 'object' is typeof value
      return table

    t = table
    # keys = Object.keys(value)
    # keys.forEach (key) ->
      # switch key
        # when 'equals'
        #   t = t.where("#{column} = ?", parsed)
        # when 'notequals'
        #   t = t.where("#{column} <> ?", parsed)
        # when 'lt'
        #   t = t.where("#{column} < ?", parsed)
        # when 'lte'
        #   t = t.where("#{column} <= ?", parsed)
        # when 'gt'
        #   t = t.where("#{column} > ?", parsed)
        # when 'gte'
        #   t = t.where("#{column} >= ?", parsed)
    return t

  siv.inherits = (constructor, superConstructor) ->
    if 'function' is typeof Object.create
      constructor.prototype = Object.create(superConstructor.prototype)
      constructor.prototype.constructor = constructor
    else
      # if there is no Object.create we use a proxyConstructor
      # to make a new object that has superConstructor as its prototype
      # and make it the prototype of constructor
      proxyConstructor = ->
      proxyConstructor.prototype = superConstructor.prototype
      constructor.prototype = new proxyConstructor
      constructor.prototype.constructor = constructor

  siv.Error = (json, previous) ->
    this.name = 'SivError'
    if siv.isError previous
      this.json = _.merge({}, previous.json, json)
    else
      this.json = json
    # console.log 'json', json
    # console.log 'previous.json', previous?.json
    # console.log 'this.json', this.json
    this.message = JSON.stringify(this.json)
    if Error.captureStackTrace?
      # second argument excludes the constructor from inclusion in the stack trace
      Error.captureStackTrace(this, this.constructor)
    return
  siv.inherits siv.Error, Error

  siv.isError = (possiblyError) ->
    possiblyError instanceof siv.Error

  return siv
)
