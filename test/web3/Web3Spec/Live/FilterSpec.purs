module Web3Spec.Live.FilterSpec (spec) where
  
import Prelude

import Control.Monad.Reader (ask)
import Data.Array ((..), snoc, length, head, sortWith)
import Data.Either (Either)
import Data.Maybe (Maybe(..))
import Data.Newtype (wrap, unwrap)
import Data.Ord.Down (Down(..))
import Data.Traversable (traverse_)
import Data.Lens ((?~), (.~), (^.))
import Effect.Aff (Aff, Fiber)
import Effect.Class (liftEffect)
import Effect.Aff.Class (class MonadAff, liftAff)
import Effect.Aff.AVar as AVar
import Effect.AVar as EAVar
import Effect.Class.Console as C
import Effect.Unsafe (unsafePerformEffect)
import Network.Ethereum.Web3 (BlockNumber, Filter, Web3Error, Change(..), _fromBlock, _toBlock, eventFilter, EventAction(..), forkWeb3, event, ChainCursor(..), Provider, UIntN, _from, _to, embed, Address)
import Network.Ethereum.Web3.Api as Api
import Network.Ethereum.Web3.Solidity.Sizes (s256, S256)
import Partial.Unsafe (unsafeCrashWith)
import Test.Spec (SpecT, before, describe, it, parallel)
import Test.Spec.Assertions (shouldEqual)
import Type.Proxy (Proxy(..))
import Web3Spec.Live.Contract.SimpleStorage as SimpleStorage
import Web3Spec.Live.Code.SimpleStorage as SimpleStorageCode
import Web3Spec.Live.Utils (assertWeb3, go, Logger, defaultTestTxOptions, ContractConfig, deployContract, mkUIntN, pollTransactionReceipt, joinWeb3Fork, hangOutTillBlock)


spec :: Provider -> SpecT Aff Unit Aff Unit
spec p =
  let env = { logger: \s -> ask >>= \logger -> liftAff $ logger s
            } 
  in go $ spec' p env

type FilterEnv m =
  { logger :: String -> m Unit 
  }

{-
Case [Past,Past] : The filter is starting and ending in the past.
Case [Past, ∞] : The filter starts in the past but continues indefinitely into the future.
Case [Future, ∞] : The fitler starts in the future and continues indefinitely into the future.
Case [Future, Future] : The fitler starts in the future and ends at a later time in the future.
-}

spec' 
  :: forall m. 
     MonadAff m
  => Provider
  -> FilterEnv m
  -> SpecT m Unit Aff Unit
spec' provider {logger} = do
  uIntV <- liftEffect $ EAVar.new 1
  let uIntsGen = mkUIntsGen uIntV
  describe "Filters" $ parallel do

    before (deployUniqueSimpleStorage provider logger) $
      it "Case [Past, Past]" \simpleStorageCfg -> do
        let {simpleStorageAddress, setter} = simpleStorageCfg
            filter = eventFilter (Proxy :: Proxy SimpleStorage.CountSet) simpleStorageAddress
        values <- uIntsGen 3
        logger $ "Searching for values " <> show values
        fiber <- monitorUntil provider logger filter (_ == aMax values)
        start <- assertWeb3 provider Api.eth_blockNumber
        traverse_ setter values
        {endingBlockV} <- joinWeb3Fork fiber
        end <- liftAff $ AVar.take endingBlockV
        let pastFilter = eventFilter (Proxy :: Proxy SimpleStorage.CountSet) simpleStorageAddress
                           # _fromBlock .~ BN start
                           # _toBlock .~  BN end
        fiber' <- monitorUntil provider logger pastFilter (const false)
        {foundValuesV} <- joinWeb3Fork fiber'
        foundValues <- liftAff $ AVar.take foundValuesV
        liftAff $ foundValues `shouldEqual` values

    before (deployUniqueSimpleStorage provider logger) $
      it "Case [Past, ∞]" \simpleStorageCfg -> do
        let {simpleStorageAddress, setter} = simpleStorageCfg
            filter1 = eventFilter (Proxy :: Proxy SimpleStorage.CountSet) simpleStorageAddress
        firstValues <- uIntsGen 3
        secondValues <- uIntsGen 3
        let allValues = firstValues <> secondValues
        logger $ "Searching for values " <> show allValues
        fiber1 <- monitorUntil provider logger filter1 (_ == aMax firstValues)
        start <- assertWeb3 provider Api.eth_blockNumber
        traverse_ setter firstValues
        _ <- joinWeb3Fork fiber1
        let filter2 = eventFilter (Proxy :: Proxy SimpleStorage.CountSet) simpleStorageAddress
                         # _fromBlock .~ BN start
                         # _toBlock   .~ Latest
        fiber2 <- monitorUntil provider logger filter2 (_ == aMax secondValues)
        traverse_ setter secondValues
        {foundValuesV} <- joinWeb3Fork fiber2
        foundValues <- liftAff $ AVar.take foundValuesV
        liftAff $ foundValues `shouldEqual` allValues

    before (deployUniqueSimpleStorage provider logger) $
      it "Case [Future, ∞]" \simpleStorageCfg -> do
        let {simpleStorageAddress, setter} = simpleStorageCfg
        values <- uIntsGen 3
        logger $ "Searching for values " <> show values
        now <- assertWeb3 provider Api.eth_blockNumber
        let later = wrap $ unwrap now + embed 3
            filter = eventFilter (Proxy :: Proxy SimpleStorage.CountSet) simpleStorageAddress
                         # _fromBlock .~ BN later
                         # _toBlock   .~ Latest
        fiber <- monitorUntil provider logger filter (_ == aMax values)
        hangOutTillBlock provider logger later
        traverse_ setter values
        {foundValuesV} <- joinWeb3Fork fiber
        foundValues <- liftAff $ AVar.take foundValuesV
        liftAff $ foundValues `shouldEqual` values

    before (deployUniqueSimpleStorage provider logger) $
      it "Case [Future, Future]" \simpleStorageCfg -> do
        let {simpleStorageAddress, setter} = simpleStorageCfg
        values <- uIntsGen 3
        logger $ "Searching for values " <> show values
        let nValues = length values
        now <- assertWeb3 provider Api.eth_blockNumber
        let later = wrap $ unwrap now + embed 3
            -- NOTE: This isn't that clean, but 2 blocks per set should be enough time
            latest = wrap $ unwrap later + embed (2 * nValues)
            filter = eventFilter (Proxy :: Proxy SimpleStorage.CountSet) simpleStorageAddress
                       # _fromBlock .~ BN later
                       # _toBlock   .~ BN latest
        fiber <- monitorUntil provider logger filter (_ == aMax values)
        hangOutTillBlock provider logger later
        traverse_ setter values
        {foundValuesV} <- joinWeb3Fork fiber
        foundValues <- liftAff $ AVar.take foundValuesV
        liftAff $ foundValues `shouldEqual` values

--------------------------------------------------------------------------------
-- Utils
--------------------------------------------------------------------------------

monitorUntil
  :: forall m.
     MonadAff m
  => Provider
  -> Logger m
  -> Filter SimpleStorage.CountSet
  -> (UIntN S256 -> Boolean)
  -> m
       ( Fiber
         ( Either Web3Error
             { endingBlockV :: AVar.AVar BlockNumber
             , foundValuesV :: AVar.AVar (Array (UIntN S256))
             }
         )
       )
monitorUntil provider logger filter p = do
  endingBlockV <- liftAff AVar.empty
  foundValuesV <- liftAff $ AVar.new []
  logger $ "Creating filter with fromBlock=" <> 
    show (filter ^. _fromBlock) <> " toBlock=" <> show (filter ^. _toBlock)
  liftAff $ forkWeb3 provider $ do
    _ <- event filter \(SimpleStorage.CountSet {_count}) -> do
      Change c <- ask
      foundSoFar <- liftAff $ AVar.take foundValuesV
      liftAff $ AVar.put (foundSoFar `snoc` _count) foundValuesV
      if p _count
        then do
          liftAff $ AVar.put c.blockNumber endingBlockV
          pure TerminateEvent
        else pure ContinueEvent
    pure {endingBlockV, foundValuesV}

deployUniqueSimpleStorage
  :: forall m.
     MonadAff m
  => Provider
  -> Logger m
  -> m { simpleStorageAddress :: Address
       , setter :: UIntN S256 -> m Unit
       } 
deployUniqueSimpleStorage provider logger = do
  contractConfig <- deployContract provider logger "SimpleStorage" $ \txOpts ->
    SimpleStorage.constructor txOpts SimpleStorageCode.deployBytecode
  pure { simpleStorageAddress: contractConfig.contractAddress
       , setter: mkSetter contractConfig provider logger
       }

mkSetter
  :: forall m.
     MonadAff m
  => ContractConfig
  -> Provider
  -> Logger m
  -> UIntN S256
  -> m Unit
mkSetter {contractAddress, userAddress} provider logger _count = do
  let txOptions = defaultTestTxOptions # _from ?~ userAddress
                                       # _to ?~ contractAddress
  logger $ "Setting count to " <> show _count
  txHash <- assertWeb3 provider $ SimpleStorage.setCount txOptions {_count}
  pollTransactionReceipt provider txHash mempty

mkUIntsGen
  :: forall m.
     MonadAff m
  => AVar.AVar Int
  -> Int
  -> m (Array (UIntN S256))
mkUIntsGen uintV n = liftAff do
  firstAvailable <- AVar.take uintV
  let nextVal = firstAvailable + n
      res = firstAvailable .. (nextVal - 1)
  AVar.put nextVal uintV
  pure $ map (mkUIntN s256) res

aMax :: forall a. Ord a => Array a -> a
aMax as = case head $ sortWith Down as of
  Nothing -> unsafeCrashWith "Can't take the max of an empty array"
  Just a -> a