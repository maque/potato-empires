{-# LANGUAGE OverloadedStrings, GeneralizedNewtypeDeriving #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}
-- An example of embedding a custom monad into
-- Scotty's transformer stack, using ReaderT to provide access
-- to a TVar containing global state.
--
-- Note: this example is somewhat simple, as our top level
-- is IO itself. The types of 'scottyT' and 'scottyAppT' are
-- general enough to allow a Scotty application to be
-- embedded into any MonadIO monad.
module StatefulScotty(
      WebM(..)
    , webM
    , gets
    , modify
    , startScotty
    , runWebMState
    , getWebMState
) where

import Control.Concurrent.STM
import Control.Monad.Reader

import Web.Scotty.Trans
import Control.Monad.State.Class
import Control.Monad.State

import Control.Applicative
-- Why 'ReaderT (TVar AppState)' rather than 'StateT AppState'?
-- With a state transformer, 'runActionToIO' (below) would have
-- to provide the state to _every action_, and save the resulting
-- state, using an MVar. This means actions would be blocking,
-- effectively meaning only one request could be serviced at a time.
-- The 'ReaderT' solution means only actions that actually modify
-- the state need to block/retry.
--
-- Also note: your monad must be an instance of 'MonadIO' for
-- Scotty to use it.
newtype WebM appState a = WebM { runWebM :: ReaderT (TVar appState) IO a }
    deriving (Monad, MonadIO, MonadReader (TVar appState), Functor, Applicative)

-- Scotty's monads are layered on top of our custom monad.
-- We define this synonym for lift in order to be explicit
-- about when we are operating at the 'WebM' layer.
webM :: MonadTrans t => WebM appState a -> t (WebM appState) a
webM = lift

getWebMState :: MonadTrans t => t (WebM appState) appState
getWebMState = 
    let
        getWebMState_ :: WebM appState appState
        getWebMState_ = ask >>= liftIO . readTVarIO
    in webM getWebMState_ 

runWebMState :: MonadTrans t => State appState a -> t (WebM appState) a
runWebMState x = 
    let 
        runWebMState_ :: State appState a -> WebM appState a
        runWebMState_ f = do
            appStateTVar <- ask
            liftIO . atomically $ do
                appState <- readTVar appStateTVar
                let (fResult, appState') = runState f appState
                writeTVar appStateTVar appState'
                return fResult
    in webM $ runWebMState_ x

-- Some helpers to make this feel more like a state monad.
--gets :: (appState -> b) -> WebM appState b
--gets f = ask >>= liftIO . readTVarIO >>= return . f

--modify :: (appState -> appState) -> WebM appState ()
--modify f = ask >>= liftIO . atomically . flip modifyTVar' f

startScotty port app initialState = do 
    sync <- newTVarIO initialState
    let runM m = runReaderT (runWebM m) sync
        runActionToIO = runM
    scottyT port runM runActionToIO app

