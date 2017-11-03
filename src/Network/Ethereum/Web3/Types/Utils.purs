module Network.Ethereum.Web3.Types.Utils
  ( getPadLength
  , padLeftSigned
  , padLeft
  , padRightSigned
  , padRight
  , toUtf8
  , fromUtf8
  , toAscii
  , fromAscii
  , toSignedHexString
  , toHexString
  , fromHexString
  , fromHexStringSigned
  ) where

import Prelude

import Data.Array (unsafeIndex, replicate)
import Data.ByteString (ByteString, toString, fromString) as BS
import Data.Int (even)
import Data.Maybe (fromJust)
import Data.String (Pattern(..), split, fromCharArray)
import Data.String as S
import Network.Ethereum.Web3.Types.BigNumber (BigNumber, toString, hexadecimal)
import Network.Ethereum.Web3.Types.Types (HexString(..), Sign(..), Signed(..), asSigned, hexLength)
import Node.Encoding (Encoding(Hex, UTF8, ASCII))
import Partial.Unsafe (unsafePartial)


-- | Computes the number of 0s needed to pad a bytestring of the input length
getPadLength :: Int -> Int
getPadLength len =
  let n = len `mod` 64
  in if n == 0 then 0 else 64 - n

-- | Pad a `Signed HexString` on the left until it has length == 0 mod 64.
padLeftSigned :: Signed HexString -> HexString
padLeftSigned (Signed s hx) =
    let padLength = getPadLength $ hexLength hx
        sgn = if s `eq` Pos then '0' else 'f'
        padding = HexString <<< fromCharArray $ replicate padLength sgn
    in padding <> hx

-- | Pad a `Signed HexString` on the right until it has length 0 mod 64.
padRightSigned :: Signed HexString -> HexString
padRightSigned (Signed s hx) =
    let padLength = getPadLength $ hexLength hx
        sgn = if s `eq` Pos then '0' else 'f'
        padding = HexString <<< fromCharArray $ replicate padLength sgn
    in hx <> padding

-- | Pad a `HexString` on the left with '0's until it has length == 0 mod 64.
padLeft :: HexString -> HexString
padLeft = padLeftSigned <<< asSigned


-- | Pad a `HexString` on the right with 0's until it has length 0 mod 64.
padRight :: HexString -> HexString
padRight = padRightSigned <<< asSigned

-- | Takes a hex string and produces the corresponding UTF8-decoded string.
-- | This breaks at the first null octet, following the web3 function `toUft8`.
--   Since 'split' always returns a nonempty list, this index is actually safe.
toUtf8 :: HexString -> String
toUtf8 (HexString hx) =
  let hx' = unsafePartial $ split (Pattern "00") hx `unsafeIndex` 0
  in flip BS.toString UTF8 $ bs hx
    where
  bs :: String -> BS.ByteString
  bs hxstr = unsafePartial $ fromJust $ BS.fromString hxstr Hex

-- | Takes a hex string and produces the corresponding ASCII decoded string.
toAscii :: HexString -> String
toAscii (HexString hx) = flip BS.toString ASCII $ unsafePartial $ fromJust $ BS.fromString hx Hex

-- | Get the 'HexString' corresponding to the UTF8 encoding.
fromUtf8 :: String -> HexString
fromUtf8 s =
  let s' = unsafePartial $ split (Pattern "\0000") s `unsafeIndex` 0
  in HexString <<< flip BS.toString Hex $ unsafePartial $ fromJust $ flip BS.fromString UTF8 $ s'

-- | Get the 'HexString' corresponding to the ASCII encoding.
fromAscii :: String -> HexString
fromAscii s = HexString <<< flip BS.toString Hex $ unsafePartial $ fromJust $ flip BS.fromString ASCII $ s

toSignedHexString :: BigNumber -> Signed HexString
toSignedHexString bn =
  let rawStr = toString hexadecimal $ bn
      str = HexString $ if even (S.length rawStr) then rawStr else "0" <> rawStr
      sgn = if bn < zero then Neg else Pos
  in Signed sgn str

toHexString :: BigNumber -> HexString
toHexString bn =
  let Signed _ n = toSignedHexString bn
  in n

foreign import fromHexString :: HexString -> BigNumber

foreign import fromHexStringSigned :: HexString -> BigNumber
