module DuckTest.Flags where

data Flag
      = Verbose |
        Version2
        deriving (Show, Enum, Ord, Eq)