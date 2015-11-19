{- This module is dedicated to untility function to make
 - using the DuckTest monad easier and less verbose-}

module DuckTest.MonadHelper where

import Data.Foldable (forM_)

import DuckTest.Monad
import Text.Printf

import Data.Maybe

{- Emit a potentially undefined variable warning-}
possibleUndefinedError :: String -> a -> DuckTest a ()
possibleUndefinedError = emitWarning . printf "Possible undefined variable %s"

{- Emit a potential attribute error -}
possibleAttributeError :: String -> String -> a -> DuckTest a ()
possibleAttributeError ident = emitWarning . printf "Possible attribute error: %s has no attributes %s" ident

possibleUnknownGlobalFunction :: String -> a -> DuckTest a ()
possibleUnknownGlobalFunction = emitWarning . printf "Possible unknown global function %s"

{- maybe function, but with args rearranged to make it easier-}
maybe' :: Maybe a -> b -> (a -> b) -> b
maybe' a b c = maybe b c a

{- Specific instance of Data.Foldable.forM_ for
 - Maybes. Used just to be more expressive. -}
whenJust :: (Monad m) => Maybe a -> (a -> m ()) -> m ()
whenJust = forM_

{- flip when just -}
whenJust' :: (Monad m) => (a -> m ()) -> Maybe a -> m ()
whenJust' = flip whenJust