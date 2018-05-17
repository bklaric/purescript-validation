-- | This module defines an applicative functor for _applicative validation_.
-- |
-- | Applicative validation differs from monadic validation using `Either` in
-- | that it allows us to collect multiple errors using a `Semigroup`, whereas
-- | `Either` terminates on the first error.

module Data.Validation.Semigroup
  ( V
  , unV
  , invalid
  , isValid
  , toEither
  ) where

import Prelude

import Control.Apply (lift2)
import Data.Bifunctor (class Bifunctor)
import Data.Either (Either(..))
import Data.Foldable (class Foldable)
import Data.Monoid (class Monoid, mempty)
import Data.Traversable (class Traversable)

-- | The `V` functor, used for applicative validation
-- |
-- | The `Applicative` instance collects multiple failures in
-- | an arbitrary `Semigroup`.
-- |
-- | For example:
-- |
-- | ```purescript
-- | validate :: Person -> V (Array Error) Person
-- | validate person = { first: _, last: _, email: _ }
-- |   <$> validateName person.first
-- |   <*> validateName person.last
-- |   <*> validateEmail person.email
-- | ```
newtype V err result = V (Either err result)

-- | Unpack the `V` type constructor, providing functions to handle the error
-- | and success cases.
unV :: forall err result r. (err -> r) -> (result -> r) -> V err result -> r
unV f _ (V (Left err)) = f err
unV _ g (V (Right result)) = g result

-- | Fail with a validation error.
invalid :: forall err result. err -> V err result
invalid = V <<< Left

-- | Test whether validation was successful or not.
isValid :: forall err result. V err result -> Boolean
isValid (V (Right _)) = true
isValid _ = false

toEither :: forall err result. V err result -> Either err result
toEither (V e) = e

fromEither :: forall left right. Semigroup left =>
  Either left right -> V left right
fromEither = V

derive instance eqV :: (Eq err, Eq result) => Eq (V err result)

derive instance ordV :: (Ord err, Ord result) => Ord (V err result)

instance showV :: (Show err, Show result) => Show (V err result) where
  show = case _ of
    V (Left err) -> "invalid (" <> show err <> ")"
    V (Right result) -> "pure (" <> show result <> ")"

derive newtype instance functorV :: Functor (V err)

derive newtype instance bifunctorV :: Bifunctor V

instance applyV :: Semigroup err => Apply (V err) where
  apply (V (Left err1)) (V (Left err2)) = V (Left (err1 <> err2))
  apply (V (Left err)) _ = V (Left err)
  apply _ (V (Left err)) = V (Left err)
  apply (V (Right f)) (V (Right x)) = V (Right (f x))

instance applicativeV :: Semigroup err => Applicative (V err) where
  pure = V <<< Right

instance semigroupV :: (Semigroup err, Semigroup a) => Semigroup (V err a) where
  append = lift2 append

instance monoidV :: (Semigroup err, Monoid a) => Monoid (V err a) where
  mempty = pure mempty

instance foldableV :: Foldable (V err) where
  foldMap = unV (const mempty)
  foldr f b = unV (const b) (flip f b)
  foldl f b = unV (const b) (f b)

instance traversableV :: Traversable (V err) where
  sequence = unV (pure <<< V <<< Left) (map (V <<< Right))
  traverse f = unV (pure <<< V <<< Left) (map (V <<< Right) <<< f)
