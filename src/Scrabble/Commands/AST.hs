{-# LANGUAGE DeriveGeneric, DeriveAnyClass #-}

-- | AST for player input (and parsing)
module Scrabble.Commands.AST where

import Data.Aeson (ToJSON, FromJSON)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import GHC.Generics
import Scrabble.Board.Board
import Scrabble.Move.WordPut
import Scrabble.Search
import Scrabble.Commands.SExpr

type Regex = String

data ScrabbleExp =
  Search  SearchExp |
  Place   WordPut   |
  Skip              |
  Quit              |
  ShowExp ShowExp -- TODO rename to ShowBoard or something
  deriving (Generic, FromJSON, ToJSON, Show)

data SearchExp =
  MatchAll  [SearchExp] |
  MatchAny  [SearchExp] |
  MatchNone [SearchExp] |
  Prim PrimSearchExp
  deriving  (Generic, FromJSON, ToJSON, Show)

data PrimSearchExp =
  StartsWith String |
  EndsWith   String |
  LetterAt Char Int |
  NoneOf [Char]     |
  AnyOf  [Char]     |
  AllOf  [Char]     |
  Only   [Char]     |
  Regex Regex
  deriving  (Generic, FromJSON, ToJSON, Show)

data ShowExp = ShowBoard Bool | ShowScores | ShowHelp
  deriving  (Generic, FromJSON, ToJSON, Show)

instance FromSExpr ScrabbleExp where
  fromSExpr (AtomSym "skip") = return Skip
  fromSExpr (AtomSym "quit") = return Quit
  fromSExpr (AtomSym ":q")   = return Quit
  fromSExpr exp@(List l) = f l where
    f [AtomSym "search", s]    = Search <$> fromSExpr s
    f (AtomSym "place" : info) = parsePlace info
    f (AtomSym "show"  : exps) = parseShowExps (showSExpr_ <$> exps)
    f _                        = parseError_ "bad command" exp
  fromSExpr bad                = parseError_ "bad command" bad

parseShowExps :: [String] -> Either String ScrabbleExp
parseShowExps = p where
  p ["board"]          = rs $ ShowBoard True
  p ["board", "clean"] = rs $ ShowBoard False
  p ["help"]           = rs $ ShowHelp
  p ["scores"]         = rs $ ShowScores
  p bad                = parseError "bad show command" (show bad)
  rs = return . ShowExp

parsePlace :: [SExpr] -> Either String ScrabbleExp
parsePlace l = parsePlace' l where
  parsePlace' [AtomSym w, o, p, AtomSym b] = f w o p b
  parsePlace' [AtomSym w, o, p]            = f w o p ""
  parsePlace' bad = parseError_ "bad placement" (List bad)
  f w o p b = do
    o' <- fromSExpr o
    p' <- fromSExpr p :: Either String Point
    Place <$> makeWordPut w o' p' b

instance FromSExpr Orientation where
  fromSExpr (AtomSym "H") = return Horizontal
  fromSExpr (AtomSym "V") = return Vertical
  fromSExpr bad = parseError_ "bad orientation" bad

instance FromSExpr SearchExp where
  fromSExpr = f where
    f (List (AtomSym "matchAll"  : rest)) = MatchAll  <$> t rest
    f (List (AtomSym "matchAny"  : rest)) = MatchAny  <$> t rest
    f (List (AtomSym "matchNone" : rest)) = MatchNone <$> t rest
    f other = Prim <$> fromSExpr other
    t = traverse fromSExpr

searchKeyWords :: Map String (String -> PrimSearchExp)
searchKeyWords = Map.fromList [
  ("startsWith",StartsWith)
 ,("endsWith"  ,EndsWith)
 ,("noneOf"    ,NoneOf)
 ,("anyOf"     ,AnyOf)
 ,("allOf"     ,AllOf)
 ,("only"      ,Only)
 ,("regex"     ,Regex) ]

instance FromSExpr PrimSearchExp where
  fromSExpr exp@(List l) = f l where
    f [AtomSym "letterAt", AtomSym p, AtomNum n] =
      return $ LetterAt (head p) (fromIntegral n)
    f [AtomSym kw, AtomSym s]                    =
      maybe err (\g -> return $ g s) (Map.lookup kw searchKeyWords)
    f   _ = err
    err = parseError_ "bad search" exp
  fromSExpr bad = parseError_ "bad search" bad

toSearch :: SearchExp -> Either String Search
toSearch = f where
  f (MatchAll  searches) = matchAll  <$> t searches
  f (MatchAny  searches) = matchAny  <$> t searches
  f (MatchNone searches) = matchNone <$> t searches
  f (Prim search)        = return $ primToSearch search
  t = traverse toSearch

primToSearch :: PrimSearchExp -> Search
primToSearch (StartsWith pat) = startsWith $ show pat
primToSearch (EndsWith   pat) = endsWith   $ show pat
primToSearch (LetterAt   l n) = containsLetterAtPos l n
primToSearch (NoneOf     ls)  = containsNone ls
primToSearch (AnyOf      ls)  = containsAny  ls
primToSearch (AllOf      ls)  = containsAll  ls
primToSearch (Only       ls)  = containsOnly ls
primToSearch (Regex r)        = regex r
