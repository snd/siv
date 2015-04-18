# siv (alpha)

[![NPM Package](https://img.shields.io/npm/v/siv.svg?style=flat)](https://www.npmjs.org/package/siv)
[![Build Status](https://travis-ci.org/snd/siv.svg?branch=master)](https://travis-ci.org/snd/siv/branches)
[![Dependencies](https://david-dm.org/snd/siv.svg)](https://david-dm.org/snd/siv)

> free your data !

**siv is a simple library that makes it very easy for a restful-API to expose an entirely safe but very powerful subset of SQL's functionality through querystrings.**

siv will also contain library-agnostic client-side utilities that allow you to build nice filter/query menus that produce querystrings that the
API can consume.

**this is in early alpha.** work in progress. in rough shape.
api is unstable. going to change a lot.
use at your own risk...

### example

let's say we have a querystring:

``` javascript
> var querystring = [
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
].join('&');
```

[qs](https://github.com/hapijs/qs) will parse that querystring into a nested object:

``` javascript
> var qs = require('qs');
```
``` javascript
> var query = qs.parse(querystring);
```
``` javascript
> query
{
  limit: '10',
  offset: '20',
  order: 'name',
  asc: 'true',
  where: {
    is_active: 'true',
    email: {
      ends: 'gmail.com',
      notcontains: 'fake',
    },
    id: {
      notin: ['100', '200'],
      lt: '1000',
    },
  },
}
```

now we can use [siv](https://github.com/snd/siv) to apply the query to a
[mesa](https://github.com/snd/mesa)
(or mohair [mohair](https://github.com/snd/mohair))
query object:

``` javascript
> var mesa = require('mesa');
```
``` javascript
> var siv = require('siv');
```
``` javascript
> var sieved = mesa.table('user');
> sieved = siv.limit(sieved, query);
> sieved = siv.offset(sieved, query);
> sieved = siv.order(sieved, query, {allow: ['name']});
> sieved = siv.boolean(sieved, query, 'is_active');
> sieved = siv.string(sieved, query, 'email');
> sieved = siv.integer(sieved, query, 'id');
```
``` javascript
> sieved.sql();
```
returns the sql query:
``` sql
SELECT * FROM "user"
WHERE ("is_active" = ?)
AND email ILIKE '%' || ?
AND email NOT ILIKE '%' || ? || '%'
AND ("id" NOT IN (?, ?))
AND ("id" < ?)
ORDER BY name ASC
LIMIT ?
OFFSET ?
```
``` javascript
> sieved.params();
[true, 'gmail.com', 'fake', 100, 200, 1000, 10, 20]
```
**more documentation (especially on error handling) is missing.
for now [see the tests](test/siv.coffee) instead.**

### features & todos

- [x] simple: immutable data, functional, side-effect free
- [x] well tested
- [x] helpful error messages that can be returned to the API consumer
- [x] chainable API
- [x] fuzzy natural language datetime and datetime range parsing
- [x] pagination
  - [x] limit
  - [x] offset
- [ ] order
  - [x] single
  - [ ] multiple
- [x] types
  - [x] nullable
    - [x] is null
    - [x] is not null
  - [ ] integer
    - [x] equals
    - [x] not equals
    - [x] lower than
    - [x] lower than or equal
    - [x] greater than
    - [x] greater than or equal
    - [x] in list
    - [x] not in list
    - [ ] shorthand for not in list
  - [ ] string
    - [x] equals
    - [x] not equals
    - [x] contains
    - [x] not contains
    - [x] begins with
    - [x] not begins with
    - [x] ends with
    - [x] not ends with
    - [x] in list
    - [x] not in list
    - [ ] shorthand for in list
  - [x] bool
  - [ ] date
    - [ ] fuzzy (today, tomorrow, in 2 days, ...)
    - [ ] range
    - [ ] in list
    - [ ] not in list
- [ ] specs (idea)
- [ ] client side tools to build up nice filter menus
- [ ] `before` and `after` for endless scrolling
- [ ] error if start of range is after end of range
- [ ] support logical operators: or, not, and (and is currently default)
- [ ] virtual columns (idea)
- [ ] deprecate mesa-find and reference to siv
- [ ] possibly share some core code with criterion ???
  - syntax trees
- [ ] move some features directly into criterion
  - [ ] $contains
  - [ ] $begins
  - [ ] $ends
- [ ] refactor code

### random chaotic collection of potential readme copy

that can be transfered through a query string via [qs]()
parse on the server side
build on the client side

client side representation is not 100% server side spec !!!

in other words

siv manipulates mesa queries based on the output of qs.

100% sql injection safe.

can be combined at will.
all sensible combinations should work.
make an issue if you feel that something should work but doesnt work.

the column operations could build up a criterion instead of building up a query

flexible spec

no assumptions over client side library.

still need to secure your api

today means the entirety of today
which means it should only look at the date part

works with both mohair and mesa

also make it possible to generate menu text from the spec

extendable

virtual columns could be made through a options.virtual
that maps names to expressions
you can also use a select to define a virtual column that
can be sorted by 

all inputs are assumed to be strings

### contribution

**TLDR: bugfixes, issues and discussion are always welcome.
ask me before implementing new features.**

i will happily merge pull requests that fix bugs with reasonable code.

i will only merge pull requests that modify/add functionality
if the changes align with my goals for this package,
are well written, documented and tested.

**communicate:** write an issue to start a discussion
before writing code that may or may not get merged.

## [license: MIT](LICENSE)
