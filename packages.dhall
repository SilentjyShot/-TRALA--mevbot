let upstream =
      https://github.com/purescript/package-sets/releases/download/psc-0.15.15-20240416/packages.dhall
        sha256:ca727657c01cc31d0e79c2113b59126b9826f4b56d20a8193be3c725599fb754

let eth-core-deps =
      https://raw.githubusercontent.com/f-o-a-m/purescript-eth-core/master/packages.dhall
        sha256:af2751772a729d58edf7056805007934e3687b3079f8a02ac514e705aeab8c42

let additions =
      { bytestrings = eth-core-deps.bytestrings
      , coroutine-transducers = 
        { dependencies = [
            "console",
            "either",
            "foldable-traversable",
            "freet",
            "functors",
            "newtype",
            "parallel",
            "prelude",
            "tailrec",
            "transformers",
            "tuples",
            "aff",
            "coroutines",
            "effect",
            "maybe",
            "psci-support"
            ]
        , repo = "https://github.com/martyall/purescript-coroutine-transducers"
        , version = "v1.0.0"
        }
      , eth-core =
        { dependencies =
          [ "argonaut"
          , "arrays"
          , "bytestrings"
          , "effect"
          , "either"
          , "foldable-traversable"
          , "foreign"
          , "functions"
          , "gen"
          , "integers"
          , "js-bigints"
          , "lists"
          , "maybe"
          , "newtype"
          , "node-buffer"
          , "nonempty"
          , "ordered-collections"
          , "partial"
          , "prelude"
          , "quotient"
          , "simple-json"
          , "strings"
          , "unfoldable"
          , "unsafe-coerce"
          ]
        , repo = "https://github.com/f-o-a-m/purescript-eth-core"
        , version = "v10.1.0"
        }
      , quotient = eth-core-deps.quotient
      }

in  upstream // additions
