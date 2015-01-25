module Main where
import Test.Hspec

import Potato.Game
import Potato.Types
import Potato.GameMap
import Control.Lens hiding (index)
import Control.Monad.State

{-# ANN module ("HLint: ignore Redundant do" :: String) #-}
{-# ANN module ("HLint: ignore Redundant bracket" :: String) #-}

spec :: Spec
spec = do
    describe "battle: " $ do
        it "subtracts units' battleValues and picks the greater" $ do
            battle (Unit 10 Redosia False) (Unit 5 Shitloadnam False) `shouldBe` (Unit 5 Redosia False)
        it "properly acts when forces are equal, preferring attacker" $ do
            battle (Unit 10 Redosia False) (Unit 10 Shitloadnam False) `shouldBe` (Unit 1 Redosia False)

    describe "conquering cities: " $ do
        it "lost battle should not change city ownership" $ do
            let initialState = createGameState $ emptyMap
                              & (ix (Point 0 0).unit) `set` (Just $ Unit 12 Shitloadnam False)
                              & (ix (Point 0 0).city) `set` (Just $ City "Red city" (Just Shitloadnam))
                              & (ix (Point 1 0).unit) `set` (Just $ Unit 10 Redosia False)

                act = move Redosia $ Move (Point 1 0) (Point 0 0)
            (execState act initialState) ^? (gameMap . ix (Point 0 0). city . traverse . conqueror . traverse) `shouldBe` (Just Shitloadnam)

    describe "game over: " $ do
        let initialState = createGameState $ emptyMap
                              & (ix (Point 0 0).unit) `set` (Just $ Unit 12 Redosia False)
                              & (ix (Point 0 0).city) `set` (Just $ City "Red city" (Just Redosia))
                              & (ix (Point 1 0).city) `set` (Just $ City "Shit city" (Just Shitloadnam))
            act = move Redosia $ Move (Point 0 0) (Point 1 0)
        it "after final move victor should be the current player" $ do
            (execState act initialState) ^. currentPlayer `shouldBe` Redosia
        it "final move's result should be game over" $ do
            (evalState act initialState)  `shouldBe` GameOver

    describe "game over in turn ending move: " $ do
        let initialState = createGameState $ emptyMap
                              & (ix (Point 0 0).unit) `set` (Just $ Unit 12 Redosia False)
                              & (ix (Point 0 0).city) `set` (Just $ City "Red city" (Just Redosia))
                              & (ix (Point 1 0).city) `set` (Just $ City "Shit city" (Just Shitloadnam))
            act = do 
                move Redosia $ Move (Point 0 0) (Point 1 0)
        it "final move's result should be game over" $ do
            (evalState act initialState)  `shouldBe` GameOver

    describe "move validation: " $ do
        it "should reject move outside of map's boundaries" $ do
            let initialState = createGameState $ emptyMap
                                  & (ix (Point 0 0).unit) `set` (Just $ Unit 12 Redosia False)
                act = move Redosia $ Move (Point 0 0) (Point (negate 1) 0)
                in (evalState act initialState) `shouldBe` InvalidMove

        it "should reject move of other player's unit" $ do
            let initialState = createGameState $ emptyMap
                                  & (ix (Point 0 0).unit) `set` (Just $ Unit 12 Shitloadnam False)
                act = move Redosia $ Move (Point 0 0) (Point 1 0)
                in (evalState act initialState) `shouldBe` InvalidMove

        it "should reject move if it's other player's turn" $ do
            let initialState = createGameState $ emptyMap
                                  & (ix (Point 0 0).unit) `set` (Just $ Unit 12 Shitloadnam False)
                act = move Shitloadnam $ Move (Point 0 0) (Point 1 0)
                in (evalState act initialState) `shouldBe` InvalidMove

        it "should reject move if there's no unit on 'from' field" $ do
            let initialState = createGameState $ emptyMap
                act = move Redosia $ Move (Point 0 0) (Point 1 0)
                in (evalState act initialState) `shouldBe` InvalidMove
                
        it "should reject second move of unit" $ do
            let initialState = createGameState $ emptyMap
                                  & (ix (Point 0 0).unit) `set` (Just $ Unit 12 Redosia False)
                act = do 
                    move Redosia $ Move (Point 0 0) (Point 1 0) 
                    move Redosia $ Move (Point 1 0) (Point 1 1)
                in (evalState act initialState) `shouldBe` InvalidMove

main :: IO ()
main = hspec spec
