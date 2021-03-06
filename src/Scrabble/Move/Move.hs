-- |
module Scrabble.Move.Move (
  module Scrabble.Move.WordPut
 ,module Scrabble.Move.Validation
 ,Move(..)
 ,createMove
 ,wordPut
) where

import Data.List (delete, foldl')
import Prelude hiding (Word)
import Scrabble.Bag
import Scrabble.Board.Board
import Scrabble.Move.Scoring
import Scrabble.Move.Validation
import Scrabble.Move.WordPut
import Scrabble.Search (containsAll)

-- |
data Move = Move {
  moveWordPut        :: WordPut -- ^ all the tiles laid down
 ,movePointsScored   :: Points  -- ^ points score in turn
 ,moveRackRemaining  :: Rack    -- ^ not yet refilled
 ,moveBoardAfterMove :: Board   -- ^ the state of the board after the move
} deriving (Eq)

-- |
createMove :: Board   -- ^
          ->  Rack    -- ^
          ->  WordPut -- ^
          ->  Dict    -- ^
          ->  Either String Move
createMove = createMove' standardValidation

-- |
createMove' :: Validator -- ^
           ->  Board     -- ^
           ->  Rack      -- ^
           ->  WordPut   -- ^
           ->  Dict      -- ^
           ->  Either String Move
createMove' validate b (Rack rack) wp dict = if valid then go else errMsg where
  errMsg        = Left "error: rack missing input letters"
  rackLetters   = fmap letter rack
  valid         = containsAll (toString putLetters) (toString rackLetters)
  putLetters    = letter <$> wordPutTiles wp
  rackRemainder = fmap fromLetter $ foldl' (flip delete) rackLetters putLetters
  go = do (newBoard, score) <- wordPut validate b wp dict
          return $ Move wp score (Rack rackRemainder) newBoard

-- | Attempt to lay tiles on the board.
--   Validate the entire move.
--   Calculate the score of the move.
wordPut :: Validator -- ^ validation algo
       ->  Board     -- ^ the board to put the word on
       ->  WordPut   -- ^ the word being put on the board
       ->  Dict      -- ^ the scrabble dictionary
       ->  Either String (Board, Score)
wordPut validate b wp dict = do
  squares <- squaresPlayedThisTurn
  let b' = nextBoard $ wordPutTiles wp
  validate (wordPutTiles wp) b b' dict
  let s  = calculateTurnScore squares b'
  return (b', s) where
    -- all the squares on the board prior to laying the tiles on them
    squaresPlayedThisTurn :: Either String [Square]
    squaresPlayedThisTurn = traverse f (tilePutPoint <$> wordPutTiles wp) where
      f p = maybe (Left $ "out of bounds: " ++ show p) Right $ elemAt b p
    -- actually put all the tiles on the board
    nextBoard :: [TilePut] -> Board
    nextBoard ts = putTiles b $ f <$> ts where
      f tp = (tilePutPoint tp, asTile tp)