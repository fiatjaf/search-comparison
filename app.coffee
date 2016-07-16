React = require 'react'
superagent = require 'superagent-promise'
levelup = require 'levelup'
memdown = require 'memdown'

{div, input, strong} = React.DOM

# libraries
sifter   = require 'sifter'
lunr     = require 'lunr'
fuzzyset = require 'fuzzyset.js'
fuse     = require 'fuse.js'
levi     = require 'levi'

# strings
superagent.get('corpus.csv').end()
.then((res) -> res.text.split('\n'))
.then((words) ->
  window.words = words

  indexes =
    fuzzyset: fuzzyset words
    sifter: new sifter ({id: word} for word in words)
    lunr: lunr ->
      @field 'word'
      @ref 'word'
    fuse: new fuse ({id: word} for word in words), keys: ['id'], include: ['score'], threshold: 0.5
    levi: levi(levelup 'levi', db: memdown).use(levi.tokenizer()).use(levi.stemmer())

  # setup lunr
  indexes.lunr.pipeline.remove(lunr.stopWordFilter)
  for word in words
    indexes.lunr.add {word: word}

  # setup levi
  indexes.levi.get 'disregard', (err) ->
    if err
      indexes.levi.batch ({type: 'put', key: w, value: {id: w}} for w in words), (err) ->
        console.log err

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
        (div {style: {float: 'left', width: '19%'}},
          (strong {}, indexname)
          (div {},
            "#{item.score.toString().slice(0, 4)}: #{item.id}"
          ) for item in @state.results[indexname] or []
        ) for indexname of @props.indexes
      )
    )

  search: (e) ->
    q = React.findDOMNode(@refs.input).value

    @props.indexes.levi.searchStream(q, limit: 23).toArray (leviResults) =>
      @setState
        results:
          fuzzyset: ({score: i[0], id: i[1]} for i in ((@props.indexes.fuzzyset.get q) or [])).slice(0, 23)
          sifter: ({score: i.score, id: words[i.id]} for i in (@props.indexes.sifter.search q, fields: ['id'], limit: 23).items)
          lunr: ({score: i.score, id: i.ref} for i in @props.indexes.lunr.search q).slice(0, 23)
          fuse: ({score: i.score, id: i.item.id}) for i in @props.indexes.fuse.search( q).slice(0, 23)
          levi: ({score: i.score, id: i.key}) for i in leviResults
