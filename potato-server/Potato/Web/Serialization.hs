{-# LANGUAGE OverloadedStrings #-}
module Potato.Web.Serialization where
import Data.Aeson.Types
import Potato.Types
import Potato.Web.Types
import Data.HashMap.Strict (union)
import Control.Applicative
import Control.Monad

-- This function is a helper that concatenates JSON data
unionObjects (Object a) (Object b) = a `union` b
unionObjects _ _ = error "You can't union anything else than objects"

combinePairs :: (ToJSON a, ToJSON b) => [(a,b)] -> [Object]
combinePairs = map (\(a,b) -> toJSON a `unionObjects` toJSON b)

instance ToJSON InitialStatePacket where
    toJSON (InitialStatePacket fields units cities timestamp) = object [
              "map" .= fields,
              "cities" .= combinePairs cities,
              "units" .= combinePairs units,
              "timestamp" .= timestamp]

instance Show MapField where
    show (MapField f u c) = fs ++ us ++ cs
        where fs = show f
              us = maybe "" show u
              cs = maybe "" show c

instance ToJSON MapField where
    toJSON = toJSON . show

instance ToJSON FieldType where
    toJSON f = case f of
        Land -> String "grass"
        Water -> String "water"

instance ToJSON Player where
    toJSON = toJSON . show

instance ToJSON City where
    toJSON (City name (Just conqueror)) = object ["name" .= name, "owner" .= conqueror]
    toJSON (City name Nothing) = object ["name" .= name]

instance ToJSON Unit where
    toJSON (Unit value owner wasMovedThisTurn) = object ["value" .= value, "owner" .= owner, "wasMoved" .= wasMovedThisTurn]

instance ToJSON Point where
    toJSON (Point x y) = object ["x" .= x, "y" .= y]
instance FromJSON Point where
    parseJSON (Object v) = Point <$>
                      v .: "x" <*>
                      v .: "y"
    parseJSON _          = mzero


instance ToJSON MovePacket where
  toJSON (MovePacket from to) = object ["from" .= from, "to" .= to]
instance FromJSON MovePacket where
    parseJSON (Object v) = MovePacket <$>
                      v .: "from" <*>
                      v .: "to"
    parseJSON _          = mzero

instance ToJSON UpdatePacket where
    toJSON (UpdatePacket units cities player movesLeft timestamp) =
        object [
            "units" .= combinePairs units,
            "cities" .= combinePairs cities,
            "currentPlayer" .= player,
            "movesLeft" .= movesLeft,
            "timestamp" .= timestamp
        ]
