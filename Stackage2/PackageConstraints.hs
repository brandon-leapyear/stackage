{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE TupleSections #-}
{-# LANGUAGE OverloadedStrings #-}
-- | The constraints on package selection for a new build plan.
module Stackage2.PackageConstraints
    ( PackageConstraints (..)
    , defaultPackageConstraints
    , defaultGlobalFlags
    , packageFlags
    , tryBuildTest
    , tryBuildBenchmark
    , ghcVerCabal
    ) where

import           Stackage2.Prelude
import qualified Stackage.Config as Old
import qualified Stackage.Types  as Old
import qualified Stackage.Select as Old

-- FIXME have the defaults here live in IO to make sure we don't have any
-- global state floating around. Will make it easier to test.

data PackageConstraints = PackageConstraints
    { pcPackages :: Map PackageName (VersionRange, Maintainer)
    -- ^ This does not include core packages or dependencies, just packages
    -- added by some maintainer.
    , pcExpectedFailures :: Set PackageName
    -- ^ At some point in the future, we should split this into Haddock
    -- failures, test failures, etc.
    }

-- | The proposed plan from the requirements provided by contributors.
defaultPackageConstraints :: PackageConstraints
defaultPackageConstraints = PackageConstraints
    { pcPackages = fmap (Maintainer . pack . Old.unMaintainer)
               <$> Old.defaultStablePackages ghcVer False
    , pcExpectedFailures = Old.defaultExpectedFailures ghcVer False
    }

-- FIXME below here shouldn't be so hard-coded

ghcVer :: Old.GhcMajorVersion
ghcVer = Old.GhcMajorVersion 7 8

ghcVerCabal :: Version
ghcVerCabal = Version [7, 8, 3] []

oldSettings :: Old.SelectSettings
oldSettings = Old.defaultSelectSettings ghcVer False

defaultGlobalFlags :: Map FlagName Bool
defaultGlobalFlags = mapFromList $
    map (, True) (map FlagName $ setToList $ Old.flags oldSettings mempty) ++
    map (, False) (map FlagName $ setToList $ Old.disabledFlags oldSettings)

packageFlags :: PackageName -> Map FlagName Bool
packageFlags (PackageName "mersenne-random-pure64") = singletonMap (FlagName "small_base") False
packageFlags _ = mempty

tryBuildTest :: PackageName -> Bool
tryBuildTest (PackageName name) = pack name `notMember` skippedTests

tryBuildBenchmark :: PackageName -> Bool
tryBuildBenchmark (PackageName name) = pack name `notMember` skippedBenchs

skippedTests :: HashSet Text
skippedTests = (old ++ ) $ setFromList $ words =<<
    [ "HTTP Octree options"
    , "hasql"
    , "bloodhound fb" -- require old hspec
    , "diagrams-haddock" -- requires old tasty
    , "hasql-postgres" -- requires old hasql
    ]
  where
    old = setFromList $ map unPackageName $ setToList $ Old.skippedTests oldSettings

skippedBenchs :: HashSet Text
skippedBenchs = setFromList $ words =<<
    [ "machines criterion-plus graphviz lifted-base pandoc stm-containers uuid"
    , "cases hasql-postgres" -- pulls in criterion-plus, which has restrictive upper bounds
    ]
