{-# LANGUAGE LambdaCase  #-}
{-# LANGUAGE Trustworthy #-}
module Network.Tox.DHT.KBucketsSpec where

import           Test.Hspec
import           Test.QuickCheck

import           Control.Monad                 (when)
import           Data.List                     (sort, sortBy)
import qualified Data.Map                      as Map
import           Data.Ord                      (comparing)
import           Data.Proxy                    (Proxy (..))
import           Network.Tox.Crypto.Key        (PublicKey)
import           Network.Tox.DHT.ClientList    (ClientList)
import qualified Network.Tox.DHT.ClientList    as ClientList
import qualified Network.Tox.DHT.Distance      as Distance
import           Network.Tox.DHT.KBuckets      (KBuckets)
import qualified Network.Tox.DHT.KBuckets      as KBuckets
import           Network.Tox.EncodingSpec
import           Network.Tox.NodeInfo.NodeInfo (NodeInfo)
import qualified Network.Tox.NodeInfo.NodeInfo as NodeInfo


makeInputKey :: Int -> Char -> PublicKey
makeInputKey pos digit =
  read $ "\"" ++ map (const '0') [0 .. pos - 1] ++ digit : map (const '0') [pos .. 63] ++ "\""


getAllBuckets :: KBuckets -> [[NodeInfo]]
getAllBuckets kBuckets =
  map (Map.elems . ClientList.nodes) (Map.elems (KBuckets.buckets kBuckets))


spec :: Spec
spec = do
  readShowSpec (Proxy :: Proxy KBuckets)

  it "does not accept adding a NodeInfo with the baseKey as publicKey" $
    property $ \kBuckets nodeInfo ->
      KBuckets.addNode nodeInfo { NodeInfo.publicKey = KBuckets.baseKey kBuckets } kBuckets
        `shouldBe`
        kBuckets

  it "adding a node to an empty k-buckets always succeeds if baseKey <> nodeKey" $
    property $ \baseKey nodeInfo ->
      let
        empty = KBuckets.empty baseKey
        kBuckets = KBuckets.addNode nodeInfo empty
      in
      if baseKey == NodeInfo.publicKey nodeInfo
      then kBuckets `shouldBe` empty
      else kBuckets `shouldNotBe` empty

  it "removing a node twice has no effect" $
    property $ \baseKey nodeInfo ->
      let
        empty        = KBuckets.empty baseKey
        afterAdd     = KBuckets.addNode nodeInfo empty
        afterRemove0 = KBuckets.removeNode (NodeInfo.publicKey nodeInfo) afterAdd
        afterRemove1 = KBuckets.removeNode (NodeInfo.publicKey nodeInfo) afterRemove0
      in
      afterRemove0 `shouldBe` afterRemove1

  it "adding a node twice has no effect" $
    property $ \baseKey nodeInfo ->
      let
        empty        = KBuckets.empty baseKey
        afterAdd0    = KBuckets.addNode nodeInfo empty
        afterAdd1    = KBuckets.addNode nodeInfo afterAdd0
      in
      afterAdd0 `shouldBe` afterAdd1

  it "never contains a NodeInfo with the public key equal to the base key" $
    property $ \kBuckets ->
      notElem (KBuckets.baseKey kBuckets) $ concatMap (map NodeInfo.publicKey) $ getAllBuckets kBuckets

  describe "each bucket list" $ do
    it "has maximum size bucketSize" $
      property $ \kBuckets ->
        mapM_
          (`shouldSatisfy` (== KBuckets.bucketSize kBuckets) . ClientList.maxSize)
          . Map.elems $ KBuckets.buckets kBuckets
    it "has base key baseKey" $
      property $ \kBuckets ->
        mapM_
          (`shouldSatisfy` (== KBuckets.baseKey kBuckets) . ClientList.baseKey)
          . Map.elems $ KBuckets.buckets kBuckets

  describe "bucketIndex" $ do
    it "returns an integer between 0 and 255 for any two non-equal keys" $
      property $ \k1 k2 ->
        when (k1 /= k2) $
          -- In our implementation, this is guaranteed by the type system, as
          -- we're using Word8, which can only represent values in this range.
          KBuckets.bucketIndex k1 k2 `shouldSatisfy` \case
            Nothing    -> False
            Just index -> index >= 0 && index <= 255

    it "is undefined for two equal keys" $
      property $ \k ->
        KBuckets.bucketIndex k k `shouldBe` Nothing

    it "returns a larger index for smaller distances and smaller index for larger distances" $
      property $ \k1 k2 k3 ->
        let
          d = Distance.xorDistance k1
          i = KBuckets.bucketIndex k1
        in
        if d k2 <= d k3
        then i k2 >= i k3
        else i k2 <= i k3

    it "produces indices 0..255 for each bit set in the key" $
      let
        zeroKey = read "\"0000000000000000000000000000000000000000000000000000000000000000\""
        inputs  = zeroKey : concatMap (\pos -> map (makeInputKey pos) ['8', '4', '2', '1']) [0 .. 63]
        outputs = Nothing : map Just [0 .. 255]
      in
      map (KBuckets.bucketIndex zeroKey) inputs `shouldBe` outputs

  describe "foldNodes" $
    it "iterates over nodes in order of distance from the base key" $
      property $ \kBuckets ->
        let
          nodes             = reverse $ KBuckets.foldNodes (flip (:)) [] kBuckets
          nodeDistance node = Distance.xorDistance (KBuckets.baseKey kBuckets) (NodeInfo.publicKey node)
        in
          nodes `shouldBe` sortBy (comparing nodeDistance) nodes
