module Network.Ethereum.Web3.Contract
 ( class EventFilter
 , eventFilter
 , event
 , event'
 , class CallMethod
 , call
 , class TxMethod
 , sendTx
 , deployContract
 , mkDataField
 ) where

import Prelude

import Control.Coroutine (runProcess)
import Data.Either (Either(..))
import Data.Functor.Tagged (Tagged, untagged)
import Data.Generic.Rep (class Generic, Constructor)
import Data.Lens ((.~), (^.), (%~), (?~))
import Data.Maybe (Maybe(..))
import Data.Symbol (class IsSymbol, SProxy(..), reflectSymbol)
import Effect.Exception (error)
import Network.Ethereum.Core.Keccak256 (toSelector)
import Network.Ethereum.Types (Address, HexString)
import Network.Ethereum.Web3.Api (eth_call, eth_sendTransaction, eth_blockNumber)
import Network.Ethereum.Web3.Contract.Events (reduceEventStream, logsStream, FilterStreamState, ChangeReceipt, EventHandler)
import Network.Ethereum.Web3.Solidity (class DecodeEvent, class GenericABIDecode, class GenericABIEncode, class RecordFieldsIso, genericABIEncode, genericFromData, genericFromRecordFields)
import Network.Ethereum.Web3.Types (class TokenUnit, CallError(..), ChainCursor(..), ETHER, Filter, NoPay, TransactionOptions, Value, Web3, _data, _fromBlock, _value, convert, throwWeb3)
import Type.Proxy (Proxy)

--------------------------------------------------------------------------------
-- * Events
--------------------------------------------------------------------------------

class EventFilter e where
    -- | Event filter structure used by low-level subscription methods
    eventFilter :: Proxy e -> Address -> Filter e

-- | run `event'` one block at a time.
event :: forall e i ni.
         DecodeEvent i ni e
      => Filter e
      -> EventHandler Web3 e
      -> Web3 (Either (FilterStreamState e) ChangeReceipt)
event fltr handler = event' fltr {windowSize: 0, trailBy: 0} handler


-- | Takes a `Filter` and a handler, as well as a windowSize.
-- | It runs the handler over the `eventLogs` using `reduceEventStream`. If no
-- | `TerminateEvent` is thrown, it then transitions to polling.
event' :: forall e i ni.
          DecodeEvent i ni e
       => Filter e
       -> { windowSize :: Int
          , trailBy :: Int
          }
       -> EventHandler Web3 e
       -> Web3 (Either (FilterStreamState e) ChangeReceipt)
event' initialFilter {windowSize, trailBy} handler = do
  currentBlock <- case initialFilter ^. _fromBlock of
    BN bn -> pure bn
    Latest -> eth_blockNumber
  let initialState = { currentBlock
                     , initialFilter
                     , windowSize
                     , trailBy
                     }
  runProcess $ reduceEventStream (logsStream initialState) handler


--------------------------------------------------------------------------------
-- * Methods
--------------------------------------------------------------------------------

-- | Class paramaterized by values which are ABIEncodable, allowing the templating of
-- | of a transaction with this value as the payload.
class TxMethod (selector :: Symbol) a where
    -- | Send a transaction for given contract 'Address', value and input data
    sendTx :: forall u.
              TokenUnit (Value (u ETHER))
           => IsSymbol selector
           => TransactionOptions u
           -> Tagged (SProxy selector) a
           -- ^ Method data
           -> Web3 HexString
           -- ^ 'Web3' wrapped tx hash

class CallMethod (selector :: Symbol) a b where
    -- | Constant call given contract 'Address' in mode and given input data
    call :: IsSymbol selector
         => TransactionOptions NoPay
         -- ^ TransactionOptions
         -> ChainCursor
         -- ^ State mode for constant call (latest or pending)
         -> Tagged (SProxy selector) a
         -- ^ Method data
         -> Web3 (Either CallError b)
         -- ^ 'Web3' wrapped result

instance txmethodAbiEncode :: (Generic a rep, GenericABIEncode rep) => TxMethod s a where
  sendTx = _sendTransaction

instance callmethodAbiEncode :: (Generic a arep, GenericABIEncode arep, Generic b brep, GenericABIDecode brep) => CallMethod s a b where
  call = _call

_sendTransaction :: forall a u rep selector .
                    IsSymbol selector
                 => Generic a rep
                 => GenericABIEncode rep
                 => TokenUnit (Value (u ETHER))
                 => TransactionOptions u
                 -> Tagged (SProxy selector) a
                 -> Web3 HexString
_sendTransaction txOptions dat = do
    let sel = toSelector <<< reflectSymbol $ (SProxy :: SProxy selector)
    eth_sendTransaction $ txdata $ sel <> (genericABIEncode <<< untagged $ dat)
  where
    txdata d = txOptions # _data .~ Just d
                         # _value %~ map convert

_call :: forall a arep b brep selector .
         IsSymbol selector
      => Generic a arep
      => GenericABIEncode arep
      => Generic b brep
      => GenericABIDecode brep
      => TransactionOptions NoPay
      -> ChainCursor
      -> Tagged (SProxy selector) a
      -> Web3 (Either CallError b)
_call txOptions cursor dat = do
    let sig = reflectSymbol $ (SProxy :: SProxy selector)
        sel = toSelector sig
        fullData = sel <> (genericABIEncode <<< untagged $ dat)
    res <- eth_call (txdata $ sel <> (genericABIEncode <<< untagged $ dat)) cursor
    case genericFromData res of
      Left err ->
        if res == mempty
          then pure <<< Left $ NullStorageError { signature: sig
                                                , _data: fullData
                                                }
          else throwWeb3 <<< error $ show err
      Right x -> pure $ Right x
  where
    txdata d  = txOptions # _data .~ Just d

deployContract :: forall a rep t.
                    Generic a rep
                 => GenericABIEncode rep
                 => TransactionOptions NoPay
                 -> HexString
                 -> Tagged t a
                 -> Web3 HexString
deployContract txOptions deployByteCode args =
  let txdata = txOptions # _data ?~ deployByteCode <> genericABIEncode (untagged args)
                         # _value %~ map convert
  in eth_sendTransaction txdata

mkDataField
  :: forall selector a name args fields l.
     IsSymbol selector
  => Generic a (Constructor name args)
  => RecordFieldsIso args fields l
  => GenericABIEncode (Constructor name args)
  => Proxy (Tagged (SProxy selector) a)
  -> Record fields
  -> HexString
mkDataField _ r =
  let sig = reflectSymbol (SProxy :: SProxy selector)
      sel = toSelector sig
      args = genericFromRecordFields r :: a
  in sel <> (genericABIEncode args)
