module Network.Ethereum.Web3.Types.Unit
  ( class Unit, fromWei, toWei
  , convert
  , U0, Wei
  , U1, Babbage
  , U2, Lovelace
  , U3, Shannon
  , U4, Szabo
  , U5, Finney
  , U6, Ether
  , U7, KEther
  , Value
  ) where

import Prelude

import Data.Foreign.Class (class Decode, class Encode)
import Data.Maybe (fromJust)
import Network.Ethereum.Web3.Types.BigNumber (BigNumber, decimal, floorBigNumber, parseBigNumber)
import Partial.Unsafe (unsafePartial)
import Type.Proxy (Proxy(..))


-- | Ether value in denomination `a`
newtype Value a = Value BigNumber

derive newtype instance eqValue :: Eq (Value a)

derive newtype instance showValue :: Show (Value a)

derive newtype instance encodeValue ::  Encode (Value a)

derive newtype instance decodeValue ::  Decode (Value a)

unValue :: forall a . Value a -> BigNumber
unValue (Value a) = a

-- | Useful for converting to and from the base denomination `Wei`
class  Unit a where
    fromWei :: BigNumber -> Value a
    toWei :: Value a -> BigNumber

-- | Convert between two denominations
convert :: forall a b . Unit a => Unit b => Value a -> Value b
convert = fromWei <<< toWei

class UnitSpec a where
    divider :: Proxy a -> BigNumber
    name    :: Value a -> String

mkValue :: forall a . UnitSpec a => BigNumber -> Value a
mkValue = modify res <<< floorBigNumber <<< (mul (divider res))
  where res :: UnitSpec a => Proxy a
        res = Proxy
        modify :: Proxy a -> BigNumber -> Value a
        modify _ = Value

instance unitUnitSpec :: UnitSpec a => Unit (Value a) where
    fromWei = Value
    toWei (Value a) = a

instance semiringUnitSpec :: UnitSpec a => Semiring (Value a) where
   add a b = Value (unValue a `add` unValue b)
   mul a b = Value (unValue a `mul` unValue b)
   zero = Value zero
   one = Value one

instance ringUnitSpec :: UnitSpec a => Ring (Value a) where
   sub a b = Value (unValue a `sub` unValue b)

instance recipValue :: UnitSpec a => DivisionRing (Value a) where
  recip (Value a) = Value $ recip a

data U0

type Wei = Value U0

instance unitSpecWei :: UnitSpec U0 where
    divider = const $ unsafeConvert "1"
    name    = const "wei"

data U1

-- | Babbage unit type
type Babbage = Value U1

instance unitSpecB :: UnitSpec U1 where
    divider = const $ unsafeConvert "1000"
    name    = const "babbage"

data U2

-- | Lovelace unit type
type Lovelace = Value U2

instance unitSpecL :: UnitSpec U2 where
    divider = const $ unsafeConvert "1000000"
    name    = const "lovelace"

data U3

-- | Shannon unit type
type Shannon = Value U3

instance unitSpecS :: UnitSpec U3 where
    divider = const $ unsafeConvert "1000000000"
    name    = const "shannon"

data U4

-- | Szabo unit type
type Szabo = Value U4

instance unitSpecSz :: UnitSpec U4 where
    divider = const $ unsafeConvert "1000000000000"
    name    = const "szabo"

data U5

-- | Finney unit type
type Finney = Value U5

instance unitSpecF :: UnitSpec U5 where
    divider = const $ unsafeConvert "1000000000000000"
    name    = const "finney"

data U6

-- | Ether unit type
type Ether  = Value U6

instance unitSpecE :: UnitSpec U6 where
    divider = const $ unsafeConvert "1000000000000000000"
    name    = const "ether"

data U7

-- | KEther unit type
type KEther = Value U7

instance unitSpecKE :: UnitSpec U7 where
    divider = const $ unsafeConvert $ "1000000000000000000000"
    name    = const "kether"

unsafeConvert :: String -> BigNumber
unsafeConvert a = unsafePartial $ fromJust <<< parseBigNumber decimal $ a
