module Hashids
    exposing
        ( Context
        , createHashidsContext
        , decode
        , decodeHex
        , decodeHexUsingSalt
        , decodeUsingSalt
        , encode
        , encodeHex
        , encodeHexUsingSalt
        , encodeList
        , encodeListUsingSalt
        , encodeUsingSalt
        , hashidsMinimum
        , hashidsSimple
        )

{-| This is an Elm port of the Hashids library by Ivan Akimov.
This is _not_ a cryptographic hashing algorithm. Hashids is typically
used to encode numbers to a format suitable for appearance in places
like urls.

See the official Hashids home page: [<http://hashids.org>](http://hashids.org)

Hashids is a small open-source library that generates short, unique,
non-sequential ids from numbers. It converts numbers like 347 into
strings like @yr8@, or a list of numbers like [27, 986] into @3kTMd@.
You can also decode those ids back. This is useful in bundling several
parameters into one or simply using them as short UIDs.


# Types

@docs Context


# Context object constructors

@docs createHashidsContext, hashidsSimple, hashidsMinimum


# Encoding and decoding

@docs encodeHex, decodeHex, encode, encodeList, decode


# Convenience wrappers

@docs encodeUsingSalt, encodeListUsingSalt, decodeUsingSalt, encodeHexUsingSalt, decodeHexUsingSalt

-}

import Array exposing (Array)
import Char
import Regex exposing (Regex)
import String
import Tuple exposing (first)


{-| A record with various internals required for encoding and decoding.
-}
type alias Context =
    { guards : String
    , seps : String
    , salt : String
    , minHashLength : Int
    , alphabet : String
    }


containsChar : Char -> String -> Bool
containsChar =
    String.contains << String.fromChar


unique : String -> String
unique str =
    let
        addIfNotMember c xs =
            if containsChar c xs then
                xs

            else
                String.cons c xs
    in
    String.foldr addIfNotMember "" str


intersect : String -> String -> String
intersect first second =
    let
        member c =
            containsChar c second
    in
    String.filter member first


exclude : String -> String -> String
exclude toBeExcluded from =
    let
        member c =
            not <| containsChar c toBeExcluded
    in
    String.filter member from


forceGet : Int -> Array Char -> Char
forceGet i axs =
    Array.get i axs |> Maybe.withDefault ' '


swap : Int -> Int -> String -> String
swap i j str =
    let
        strArray =
            Array.fromList <| String.toList str

        iElem =
            forceGet i strArray

        jElem =
            forceGet j strArray
    in
    Array.set i jElem strArray
        |> Array.set j iElem
        |> Array.toList
        |> String.fromList


{-| reorder a string acording to salt
-}
reorder : String -> String -> String
reorder string salt =
    let
        saltLen =
            String.length salt

        alphaLen =
            String.length string

        saltArray =
            Array.fromList <| String.toList salt

        shuffle i index integerSum str =
            if i > 0 then
                let
                    newIndex =
                        modBy saltLen index

                    integer =
                        Char.toCode <| forceGet newIndex saltArray

                    newIntegerSum =
                        integerSum + integer

                    j =
                        modBy i (integer + newIndex + newIntegerSum)

                    newStr =
                        swap i j str
                in
                shuffle (i - 1) (newIndex + 1) newIntegerSum newStr

            else
                str
    in
    if saltLen == 0 then
        string

    else
        shuffle (alphaLen - 1) 0 0 string


{-| Create a context object using the given salt, a minimum hash length, and
a custom alphabet. If you only need to supply the salt, or the first two
arguments, use 'hashidsSimple' or 'hashidsMinimum' instead.

Changing the alphabet is useful if you want to make your hashes unique,
i.e., create hashes different from those generated by other applications
relying on the same algorithm.

-}
createHashidsContext :
    String
    -- Salt
    -> Int
    --  Minimum required hash length
    -> String
    --  Alphabet
    -> Context
createHashidsContext salt minHashLen alphabet =
    let
        minAlphabetLength =
            16

        sepDiv =
            3.5

        guardDiv =
            12

        clean alpha =
            let
                seps =
                    "cfhistuCFHISTU"

                seps1 =
                    intersect seps alpha

                hasSpaces =
                    String.contains " " alpha

                alpha1 =
                    exclude seps1 <| unique alpha

                alphabetIsSmall =
                    String.length (alpha1 ++ seps1) < minAlphabetLength
            in
            case ( hasSpaces, alphabetIsSmall ) of
                ( True, _ ) ->
                    -- "alphabet provided has spaces, using default"
                    ( seps, exclude seps defaultAlphabet )

                ( _, True ) ->
                    -- "alphabet too small, using default"
                    ( seps, exclude seps defaultAlphabet )

                ( False, False ) ->
                    ( seps1, alpha1 )

        validSeps ( seps, alpha ) =
            let
                seps1 =
                    reorder seps salt

                lenSeps =
                    String.length seps1

                lenAlpha =
                    String.length alpha

                minSeps =
                    ceiling <| toFloat lenAlpha / sepDiv
            in
            if lenSeps < minSeps then
                let
                    minSeps1 =
                        if minSeps == 1 then
                            2

                        else
                            minSeps
                in
                if minSeps1 > lenSeps then
                    let
                        splitAt =
                            minSeps1 - lenSeps

                        seps2 =
                            seps1 ++ String.left splitAt alpha

                        alpha1 =
                            String.dropLeft splitAt alpha
                    in
                    ( seps2, alpha1 )

                else
                    ( seps1, alpha )

            else
                ( seps1, alpha )

        withGuard ( seps, alpha ) =
            let
                alpha1 =
                    reorder alpha salt

                lenAlpha =
                    String.length alpha

                numGuards =
                    ceiling <| toFloat lenAlpha / guardDiv
            in
            if lenAlpha < 3 then
                ( String.dropLeft numGuards seps, alpha1, String.left numGuards seps )

            else
                ( seps, String.dropLeft numGuards alpha1, String.left numGuards alpha1 )

        ( seps1b, alphabet1, guards ) =
            clean alphabet
                |> validSeps
                |> withGuard
    in
    { guards = guards
    , seps = seps1b
    , salt = salt
    , minHashLength = minHashLen
    , alphabet = alphabet1
    }


defaultAlphabet : String
defaultAlphabet =
    "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890"


{-| Create a context object using the default alphabet and the provided salt,
without any minimum required length.
-}
hashidsSimple :
    String
    -- Salt
    -> Context
hashidsSimple salt =
    createHashidsContext salt 0 defaultAlphabet


{-| Create a context object using the default alphabet and the provided salt.
The generated hashes will have a minimum length as specified by the second
argument.
-}
hashidsMinimum :
    String
    -- Salt
    -> Int
    --  Minimum required hash length
    -> Context
hashidsMinimum salt minimum =
    createHashidsContext salt minimum defaultAlphabet


{-| Decode a hash generated with 'encodeHex'.

Example use:

    decodeHex context "yzgwD"

-}
decodeHex :
    Context
    -- Hashids context object
    -> String
    --  Hash
    -> String
decodeHex context hash =
    let
        numbers =
            decode context hash
    in
    concatMap (\n -> String.dropLeft 1 <| String.fromInt n) numbers


concatMap : (a -> String) -> List a -> String
concatMap f =
    String.concat << List.map f


{-| Encode a hexadecimal number.

Example use:

    encodeHex context "ff83"

-}
encodeHex :
    Context
    --  A Hashids context object
    -> String
    --  Hexadecimal number represented as a string
    -> String
encodeHex context str =
    if String.all Char.isHexDigit str then
        encodeList context <| List.map (\chunk -> fromHex ("1" ++ chunk)) <| chunksOf 12 str

    else
        ""


chunksOf : Int -> String -> List String
chunksOf size origStr =
    let
        split str acc =
            if String.length str > size then
                split (String.dropRight size str) (String.right size str :: acc)

            else
                str :: acc
    in
    split origStr []


fromHex : String -> Int
fromHex hex =
    let
        toDig n =
            case Char.toUpper n of
                '1' ->
                    1

                '2' ->
                    2

                '3' ->
                    3

                '4' ->
                    4

                '5' ->
                    5

                '6' ->
                    6

                '7' ->
                    7

                '8' ->
                    8

                '9' ->
                    9

                'A' ->
                    10

                'B' ->
                    11

                'C' ->
                    12

                'D' ->
                    13

                'E' ->
                    14

                'F' ->
                    15

                _ ->
                    0

        go current ( acc, pow ) =
            ( acc + toDig current * (16 ^ pow), pow + 1 )
    in
    first <| String.foldr go ( 0, 0 ) hex


{-| Decode a hash.

Example use:

    hash =
        let
            context =
                hashidsSimple "this is my salt"
        in
        decode context "rD"


    -- == [5]

-}
decode :
    Context
    -- A Hashids context object
    -> String
    --  Hash
    -> List Int
decode context hash =
    if hash == "" then
        []

    else
        let
            { guards, seps, salt, minHashLength, alphabet } =
                context

            guardParts =
                splitOn guards hash

            guardPartsLen =
                List.length guardParts

            hash1 =
                Maybe.withDefault "" <|
                    List.head <|
                        if (2 <= guardPartsLen) && (guardPartsLen <= 3) then
                            List.drop 1 guardParts

                        else
                            guardParts

            hash2 =
                String.dropLeft 1 hash1

            lotteryChar =
                String.left 1 hash1

            hashParts =
                splitOn seps hash2

            numbers =
                if String.isEmpty hash1 then
                    []

                else
                    first <| List.foldl go ( [], alphabet ) hashParts

            go part ( acc, alpha ) =
                let
                    alphaSalt =
                        String.left (String.length alpha) (lotteryChar ++ salt ++ alpha)

                    alpha1 =
                        reorder alpha alphaSalt
                in
                ( acc ++ [ unhash part alpha1 ], alpha1 )

            unhash part alpha =
                let
                    partLen =
                        String.length part

                    alphaLen =
                        String.length alpha

                    partList =
                        List.map String.fromChar <| String.toList part

                    position c =
                        String.indexes c alpha |> List.head >> Maybe.withDefault 0
                in
                List.sum <| List.indexedMap (\i c -> position c * alphaLen ^ (partLen - i - 1)) partList
        in
        if encodeList context numbers /= hash then
            []

        else
            numbers


regex : String -> Regex
regex str =
    Maybe.withDefault Regex.never <|
        Regex.fromString str


splitOn : String -> String -> List String
splitOn splitters str =
    Regex.split (regex <| "[" ++ splitters ++ "]") str


{-| Encode a single number.

Example use:

    hash =
        let
            context =
                hashidsSimple "this is my salt"
        in
        encode context 5


    -- == "rD"

-}
encode :
    Context
    --  A Hashids context object
    -> Int
    -- Number to encode
    -> String
encode context n =
    encodeList context [ n ]


{-| Encode a list of numbers.

Example use:

    hash =
        let
            context =
                hashidsSimple "this is my salt"
        in
        encodeList context [ 2, 3, 5, 7, 11 ]


    -- == "EOurh6cbTD"

-}
encodeList :
    Context
    --  A Hashids context object
    -> List Int
    --  List of numbers
    -> String
encodeList context numbers =
    let
        { guards, seps, salt, minHashLength, alphabet } =
            context

        alphaLen =
            String.length alphabet

        sepsLen =
            String.length seps

        valuesHash =
            List.sum <| List.indexedMap (\i n -> modBy (i + 100) n) numbers

        --encoded = lottery = alphabet[values_hash % len(alphabet)]
        lottery =
            strGet (modBy alphaLen valuesHash) alphabet

        hash value alpha acc =
            let
                alphaLen_ =
                    String.length alpha

                value1 =
                    value // alphaLen

                acc1 =
                    strGet (modBy alphaLen_ value) alpha ++ acc
            in
            if value1 == 0 then
                acc1

            else
                hash value1 alpha acc1

        go ( i, value ) ( acc, alpha ) =
            let
                alphaSalt =
                    String.left alphaLen (lottery ++ salt ++ alpha)

                alpha1_ =
                    reorder alpha alphaSalt

                last =
                    hash value alpha1_ ""

                firstCode =
                    ordOfIdx 0 last

                value1 =
                    modBy (firstCode + i) value

                sepEnc =
                    strGet (modBy sepsLen value1) seps
            in
            ( acc ++ [ last ++ sepEnc ], alpha1_ )

        ( encodedList, alpha1 ) =
            List.indexedMap (\a b -> ( a, b )) numbers
                |> List.foldl go ( [ lottery ], alphabet )

        encodedPre =
            String.concat encodedList

        encoded =
            String.dropRight 1 encodedPre

        -- cut off last separator
    in
    if String.length encoded >= minHashLength then
        encoded

    else
        ensureLength encoded minHashLength alpha1 guards valuesHash


strGet : Int -> String -> String
strGet i str =
    String.left 1 <| String.dropLeft i str


ordOfIdx : Int -> String -> Int
ordOfIdx i str =
    String.dropLeft i str
        |> String.toList
        |> List.head
        |> Maybe.map Char.toCode
        |> Maybe.withDefault 0


ensureLength : String -> Int -> String -> String -> Int -> String
ensureLength encoded minHashLength alphabet guards valuesHash =
    let
        guardsLen =
            String.length guards

        guardIndex =
            modBy guardsLen (valuesHash + ordOfIdx 0 encoded)

        acc =
            strGet guardIndex guards ++ encoded

        guardIndex1 =
            modBy guardsLen (valuesHash + ordOfIdx 2 acc)

        acc1 =
            if String.length acc < minHashLength then
                acc ++ strGet guardIndex1 guards

            else
                acc

        splitAt =
            String.length alphabet // 2

        extend encoded_ alpha =
            let
                alpha1 =
                    reorder alpha alpha

                encodedPre =
                    String.dropLeft splitAt alpha1
                        ++ encoded_
                        ++ String.left splitAt alpha1

                excess =
                    String.length encodedPre - minHashLength

                fromIndex =
                    excess // 2

                encoded1 =
                    if excess > 0 then
                        String.left minHashLength <| String.dropLeft fromIndex encodedPre

                    else
                        encodedPre
            in
            if String.length encoded1 < minHashLength then
                extend encoded1 alpha1

            else
                encoded1
    in
    extend acc1 alphabet


{-| Encode a number using the provided salt.

This convenience function creates a context with the default alphabet.
If the same context is used repeatedly, use 'encode' with one of the
constructors instead.

-}
encodeUsingSalt :
    String
    --  Salt
    -> Int
    --  Number
    -> String
encodeUsingSalt =
    encode << hashidsSimple


{-| Encode a list of numbers using the provided salt.

This function wrapper creates a context with the default alphabet.
If the same context is used repeatedly, use 'encodeList' with one of the
constructors instead.

-}
encodeListUsingSalt :
    String
    --  Salt
    -> List Int
    --  Numbers
    -> String
encodeListUsingSalt =
    encodeList << hashidsSimple


{-| Decode a hash using the provided salt.

This convenience function creates a context with the default alphabet.
If the same context is used repeatedly, use 'decode' with one of the
constructors instead.

-}
decodeUsingSalt :
    String
    -- Salt
    -> String
    -- Hash
    -> List Int
decodeUsingSalt =
    decode << hashidsSimple


{-| Shortcut for 'encodeHex'.
-}
encodeHexUsingSalt :
    String
    -- Salt
    -> String
    -- Hexadecimal number represented as a string
    -> String
encodeHexUsingSalt =
    encodeHex << hashidsSimple


{-| Shortcut for 'decodeHex'.
-}
decodeHexUsingSalt :
    String
    -- Salt
    -> String
    -- Hash
    -> String
decodeHexUsingSalt =
    decodeHex << hashidsSimple
