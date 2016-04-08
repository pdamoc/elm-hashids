# elm-hashids

Elm port of the Hashids library. http://hashids.org

##### Install: 

```
elm-package install pdamoc/elm-hashids
```

##### Hello, World:

```elm
import Html exposing (text, br)
import Hashids exposing (hashidsSimple, encodeList, decode)

main : Html
main = 
  let 
    hashids = hashidsSimple "this is my salt"
    ids = encodeList hashids [1, 2, 3]
    numbers = decode hashids ids
  in 
    div []
    [ text ids
    , br [] []
    , text <| toString numbers
    ]
```
