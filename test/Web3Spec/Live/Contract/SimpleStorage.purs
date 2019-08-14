module Web3Spec.Live.Contract.SimpleStorage where

import Prelude

import Data.Either (Either)
import Data.Functor.Tagged (Tagged, tagged, untagged)
import Data.Generic.Rep (class Generic)
import Data.Generic.Rep.Eq (genericEq)
import Data.Generic.Rep.Show (genericShow)
import Data.Lens ((.~))
import Data.Maybe (Maybe(..), fromJust)
import Data.Newtype (class Newtype)
import Data.Symbol (SProxy)
import Network.Ethereum.Web3 (_address, _topics, call, class EventFilter, deployContract, sendTx)
import Network.Ethereum.Web3.Contract.Internal (uncurryFields)
import Network.Ethereum.Web3.Solidity (D2, D5, D6, DOne, Tuple0(..), Tuple1(..), UIntN, class IndexedEvent, unTuple1)
import Network.Ethereum.Web3.Solidity.Size (type (:&))
import Network.Ethereum.Web3.Types (CallError, ChainCursor, HexString, NoPay, TransactionOptions, Web3, defaultFilter, mkHexString)
import Partial.Unsafe (unsafePartial, unsafePartialBecause)

import Web3Spec.LiveSpec.Utils (mkHexString')

--------------------------------------------------------------------------------
-- Deployment
--------------------------------------------------------------------------------

deployBytecode :: HexString
deployBytecode = mkHexString' "6060604052341561000f57600080fd5b7fb94ae47ec9f4248692e2ecf9740b67ab493f3dcc8452bedc7d9cd911c28d1ca5436040518082815260200191505060405180910390a1610107806100556000396000f3006060604052600436106049576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff16806306661abd14604e578063d14e62b8146074575b600080fd5b3415605857600080fd5b605e6094565b6040518082815260200191505060405180910390f35b3415607e57600080fd5b60926004808035906020019091905050609a565b005b60005481565b806000819055507fa32bc18230dd172221ac5c4821a5f1f1a831f27b1396d244cdd891c58f132435816040518082815260200191505060405180910390a1505600a165627a7a7230582023412a39f8bfbbb1939c02b894f7f224f2dbb2fda0ca79b2084ff59e65fe1f980029"

--------------------------------------------------------------------------------
-- | CountFn
--------------------------------------------------------------------------------


type CountFn = Tagged (SProxy "count()") (Tuple0 )

count :: TransactionOptions NoPay -> ChainCursor -> Web3 (Either CallError (UIntN (D2 :& D5 :& DOne D6)))
count x0 cm = map unTuple1 <$> call x0 cm ((tagged $ Tuple0 ) :: CountFn)

--------------------------------------------------------------------------------
-- | SetCountFn
--------------------------------------------------------------------------------


type SetCountFn = Tagged (SProxy "setCount(uint256)") (Tuple1 (UIntN (D2 :& D5 :& DOne D6)))

setCount :: TransactionOptions NoPay -> { _count :: (UIntN (D2 :& D5 :& DOne D6)) } -> Web3 HexString
setCount x0 r = uncurryFields  r $ setCount' x0
   where
    setCount' :: TransactionOptions NoPay -> Tagged (SProxy "_count") (UIntN (D2 :& D5 :& DOne D6)) -> Web3 HexString
    setCount' y0 y1 = sendTx y0 ((tagged $ Tuple1 (untagged y1 )) :: SetCountFn)

--------------------------------------------------------------------------------
-- | ConstructorFn
--------------------------------------------------------------------------------


type ConstructorFn = Tagged (SProxy "constructor()") (Tuple0 )

constructor :: TransactionOptions NoPay -> HexString -> Web3 HexString
constructor x0 bc = deployContract x0 bc ((tagged $ Tuple0 ) :: ConstructorFn)

--------------------------------------------------------------------------------
-- | CountSet
--------------------------------------------------------------------------------


newtype CountSet = CountSet {_count :: (UIntN (D2 :& D5 :& DOne D6))}

derive instance newtypeCountSet :: Newtype CountSet _

instance eventFilterCountSet :: EventFilter CountSet where
	eventFilter _ addr = defaultFilter
		# _address .~ Just addr
		# _topics .~ Just [Just ( unsafePartial $ fromJust $ mkHexString "a32bc18230dd172221ac5c4821a5f1f1a831f27b1396d244cdd891c58f132435")]

instance indexedEventCountSet :: IndexedEvent (Tuple0 ) (Tuple1 (Tagged (SProxy "_count") (UIntN (D2 :& D5 :& DOne D6)))) CountSet where
  isAnonymous _ = false

derive instance genericCountSet :: Generic CountSet _

instance eventGenericCountSetShow :: Show CountSet where
	show = genericShow

instance eventGenericCountSeteq :: Eq CountSet where
	eq = genericEq

--------------------------------------------------------------------------------
-- | Deployed
--------------------------------------------------------------------------------


newtype Deployed = Deployed {_blockNumber :: (UIntN (D2 :& D5 :& DOne D6))}

derive instance newtypeDeployed :: Newtype Deployed _

instance eventFilterDeployed :: EventFilter Deployed where
	eventFilter _ addr = defaultFilter
		# _address .~ Just addr
		# _topics .~ Just [Just ( unsafePartial $ fromJust $ mkHexString "b94ae47ec9f4248692e2ecf9740b67ab493f3dcc8452bedc7d9cd911c28d1ca5")]

instance indexedEventDeployed :: IndexedEvent (Tuple0 ) (Tuple1 (Tagged (SProxy "_blockNumber") (UIntN (D2 :& D5 :& DOne D6)))) Deployed where
  isAnonymous _ = false

derive instance genericDeployed :: Generic Deployed _

instance eventGenericDeployedShow :: Show Deployed where
	show = genericShow

instance eventGenericDeployedeq :: Eq Deployed where
	eq = genericEq
