# elm-hashids

Elm port of the Hashids library. http://hashids.org

##### Install: 

```
elm install pdamoc/elm-hashids
```

##### Hello, World:

```elm
import Html exposing (..)
import Hashids exposing (..)

hashids = hashidsSimple "this is my salt"
ids = encodeList hashids [1, 2, 3]
numbers = decode hashids ids

main : Html
main = 
  div []
    [ text ids
    , br [] []
    , text <| Debug.toString numbers
    ]
```
