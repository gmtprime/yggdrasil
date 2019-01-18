locals_without_parens = [
  add_env: 3,
  add_env: 4
]

[
  inputs: ["mix.exs", "{lib,test}/**/*.{ex,exs}"],
  line_length: 80,
  locals_without_parens: locals_without_parens,
  export: [
    locals_without_parens: locals_without_parens
  ]
]
