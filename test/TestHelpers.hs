{-# LANGUAGE TemplateHaskell #-}
module TestHelpers where

import Data.Aeson
import Data.Monoid (mempty)
import Data.List
import Scrabble.Dictionary
import System.IO.Unsafe
import Test.Framework (testGroup)
import Test.Framework.Providers.HUnit
import Test.Framework.Providers.QuickCheck2 (testProperty)
import Test.QuickCheck hiding (Success)
import Test.QuickCheck.Instances.Char
import Test.HUnit

dict = unsafePerformIO dictionary

p s t = testProperty (s ++ "_property" ) t
u s t = testCase     (s ++ "_unit_test") t

props g ps = testGroup g $ f <$> ps where f (name,prop) = testProperty name prop
units g us = testGroup g $ f <$> us where f (name,test) = testCase     name test

allEqual :: (Eq a, Show a) => [a] -> IO ()
allEqual (x1:x2:xs) = (x1 @?= x2) >> allEqual (x2:xs)
allEqual _          = return ()

eq_reflexive :: Eq a => a -> Bool
eq_reflexive x = x == x

roundTripJSON :: (FromJSON a, ToJSON a, Eq a, Show a) => a -> Bool
roundTripJSON a = fromJSON (toJSON a) == Success a && (eitherDecode $ encode a) == Right a