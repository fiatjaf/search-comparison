Promise = require 'promise'
React = require 'react'
superagent = require 'superagent-promise'
fuzzy = require 'fuzzy'
fastFuzzy = require 'fast-fuzzy'

{div, a, input, strong} = React.DOM

# libraries
sifter   = require 'sifter'
lunr     = require 'lunr'
fuzzyset = require 'fuzzyset.js'
fuse     = require 'fuse.js'

# strings
superagent.get('corpus.csv').end()
.then((res) -> res.text.split('\n'))
.then((words) ->
  window.words = words

  indexes =
    fuzzyset: fuzzyset words
    sifter: new sifter ({id: word} for word in words)
    fuzzy: true
    lunr: lunr ->
      @field 'word'
      @ref 'word'
    fuse: new fuse ({id: word} for word in words), keys: ['id'], include: ['score'], threshold: 0.5
    'fast-fuzzy': true

  # setup lunr
  indexes.lunr.pipeline.remove(lunr.stopWordFilter)
  for word in words
    indexes.lunr.add {word: word}

  return indexes
)
.then((indexes) ->
  React.render React.createElement(Main, {indexes: indexes}), document.getElementsByTagName('main')[0]
).catch((x) -> console.log x)

Main = React.createClass
  getInitialState: ->
    results: {}

  render: ->
    (div {},
      (input
        placeholder: 'search for common words here'
        onChange: @search
        ref: 'input'
        style: {display: 'block', clear: 'both', width: '300px'}
      )
      (div {},
        (div {style: {float: 'left', width: '16%'}},
          (strong {},
            (a {href: 'https://npmjs.com/package/' + indexname, target: '_blank'}, indexname)
          )
          (div {},
            "#{item.score.toString().slice(0, 4)}: #{item.id}"
          ) for item in @state.results[indexname] or []
        ) for indexname of @props.indexes
      )
    )

  timeout: null,

  search: (e) ->
    q = React.findDOMNode(@refs.input).value

    clearTimeout(@timeout)

    @setState
      results:
        fuzzyset: ({score: i[0], id: i[1]} for i in ((@props.indexes.fuzzyset.get q) or [])).slice(0, 23)
        sifter: ({score: i.score, id: words[i.id]} for i in (@props.indexes.sifter.search q, fields: ['id'], limit: 23).items)
        lunr: ({score: i.score, id: i.ref} for i in @props.indexes.lunr.search q).slice(0, 23)
        fuzzy: ({score: i.score, id: i.string} for i in fuzzy.filter q, window.words).slice(0, 23)
        fuse: ({score: i.score, id: i.item.id} for i in @props.indexes.fuse.search q).slice(0, 23)
        'fast-fuzzy': ({score: i.score, id: i.item} for i in fastFuzzy.search(q, window.words, returnScores: true)).slice(0, 23)

    @timeout = setTimeout(() ->
      window.tc && tc 1
    , 3000)
