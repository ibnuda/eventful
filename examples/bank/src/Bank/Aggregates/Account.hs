module Bank.Aggregates.Account
  ( Account (..)
  , AccountEvent (..)
  , AccountOpened (..)
  , AccountCredited (..)
  , AccountDebited (..)
  , AccountProjection
  , accountProjection
  , AccountCommand (..)
  , OpenAccountData (..)
  , CreditAccountData (..)
  , DebitAccountData (..)
  , AccountCommandError (..)
  , NotEnoughFundsData (..)
  , AccountAggregate
  , accountAggregate
  ) where

import Data.Aeson.TH

import Eventful

import Bank.Json

data Account =
  Account
  { accountBalance :: Double
  , accountOwner :: Maybe String
  } deriving (Show, Eq)

data AccountOpened =
  AccountOpened
  { accountOpenedOwner :: String
  , accountOpenedInitialFunding :: Double
  } deriving (Show, Eq)

data AccountCredited =
  AccountCredited
  { accountCreditedAmount :: Double
  , accountCreditedReason :: String
  } deriving (Show, Eq)

data AccountDebited =
  AccountDebited
  { accountDebitedAmount :: Double
  , accountDebitedReason :: String
  } deriving (Show, Eq)

data AccountEvent
  = AccountAccountOpened AccountOpened
  | AccountAccountCredited AccountCredited
  | AccountAccountDebited AccountDebited
  deriving (Show, Eq)

deriveJSON (unPrefixLower "account") ''Account
deriveJSON (unPrefixLower "accountOpened") ''AccountOpened
deriveJSON (unPrefixLower "accountCredited") ''AccountCredited
deriveJSON (unPrefixLower "accountDebited") ''AccountDebited
deriveJSON defaultOptions ''AccountEvent

applyAccountEvent :: Account -> AccountEvent -> Account
applyAccountEvent account (AccountAccountOpened (AccountOpened name amount)) =
  account { accountOwner = Just name, accountBalance = amount }
applyAccountEvent account (AccountAccountCredited (AccountCredited amount _)) =
  account { accountBalance = accountBalance account + amount }
applyAccountEvent account (AccountAccountDebited (AccountDebited amount _)) =
  account { accountBalance = accountBalance account - amount }

type AccountProjection = Projection Account AccountEvent

accountProjection :: AccountProjection
accountProjection =
  Projection
  (Account 0 Nothing)
  applyAccountEvent

data AccountCommand
  = OpenAccount OpenAccountData
  | CreditAccount CreditAccountData
  | DebitAccount DebitAccountData
  deriving (Show, Eq)

data OpenAccountData =
  OpenAccountData
  { openAccountDataOwner :: String
  , openAccountDataInitialFunding :: Double
  } deriving (Show, Eq)

data CreditAccountData =
  CreditAccountData
  { creditAccountDataAmount :: Double
  , creditAccountDataReason :: String
  } deriving (Show, Eq)

data DebitAccountData =
  DebitAccountData
  { debitAccountDataAmount :: Double
  , debitAccountDataReason :: String
  } deriving (Show, Eq)

data AccountCommandError
  = AccountAlreadyOpenError
  | InvalidInitialDepositError
  | NotEnoughFundsError NotEnoughFundsData
  deriving (Show, Eq)

data NotEnoughFundsData =
  NotEnoughFundsData
  { notEnoughFundsDataRemainingFunds :: Double
  } deriving  (Show, Eq)

deriveJSON (unPrefixLower "notEnoughFundsData") ''NotEnoughFundsData
deriveJSON defaultOptions ''AccountCommandError

applyAccountCommand :: Account -> AccountCommand -> Either AccountCommandError [AccountEvent]
applyAccountCommand account (OpenAccount (OpenAccountData owner amount)) =
  case accountOwner account of
    Just _ -> Left AccountAlreadyOpenError
    Nothing ->
      if amount < 0
      then Left InvalidInitialDepositError
      else Right [AccountAccountOpened $ AccountOpened owner amount]
applyAccountCommand _ (CreditAccount (CreditAccountData amount reason)) =
  Right [AccountAccountCredited $ AccountCredited amount reason]
applyAccountCommand account (DebitAccount (DebitAccountData amount reason)) =
  if accountBalance account - amount < 0
  then Left $ NotEnoughFundsError (NotEnoughFundsData $ accountBalance account)
  else Right [AccountAccountDebited $ AccountDebited amount reason]

type AccountAggregate = Aggregate Account AccountEvent AccountCommand AccountCommandError

accountAggregate :: AccountAggregate
accountAggregate = Aggregate applyAccountCommand accountProjection
