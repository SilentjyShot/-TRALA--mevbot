module Web3Spec.Live.SimpleStorage (spec) where

import Prelude

import Data.Either (isRight)
import Data.Lens ((?~))
import Data.Tuple (Tuple(..))
import Effect.Aff (Aff)
import Network.Ethereum.Web3 (ChainCursor(..), Provider, _from, _to, runWeb3)
import Network.Ethereum.Web3.Api as Api
import Test.Spec (SpecT, beforeAll, describe, it)
import Test.Spec.Assertions (shouldEqual, shouldSatisfy)
import Type.Proxy (Proxy(..))
import Web3Spec.Live.Contract.SimpleStorage as SimpleStorage
import Web3Spec.LiveSpec.Utils (assertWeb3, defaultTestTxOptions, deployContract, mkUInt, takeEvent)

spec :: Provider -> SpecT Aff Unit Aff Unit
spec provider =
  describe "It should be able to deploy and test a simple contract" $
    beforeAll (deployContract provider "SimpleStorage" $ \txOpts -> SimpleStorage.constructor txOpts SimpleStorage.deployBytecode) $

      it "Can deploy a contract, verify the contract storage, make a transaction, get get the event, make a call" $ \simpleStorageCfg -> do
        let {contractAddress: simpleStorageAddress, userAddress} = simpleStorageCfg
            newCount = mkUInt one
            txOpts = defaultTestTxOptions # _from ?~ userAddress
                                          # _to ?~ simpleStorageAddress
            setCountTx = SimpleStorage.setCount txOpts {_count: newCount}
        Tuple _ (SimpleStorage.CountSet {_count}) <- assertWeb3 provider $ takeEvent (Proxy :: Proxy SimpleStorage.CountSet) simpleStorageAddress setCountTx
        _count `shouldEqual` newCount
        eRes' <- runWeb3 provider $ Api.eth_getStorageAt simpleStorageAddress zero Latest
        eRes' `shouldSatisfy` isRight
