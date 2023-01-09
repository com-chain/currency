# -*- coding: utf-8 -*-

from pytest import fixture

from brownie import ComChainCurrency, accounts, reverts
from brownie.network.contract import ContractCall, ContractTx


class Account(object):

    def __init__(self, currency, account):
        self._account = account
        self._currency = currency

    def __getattr__(self, key):
        if hasattr(self._currency, key):
            fn = getattr(self._currency, key)
            if isinstance(fn, ContractCall):
                if len(fn.abi["inputs"]) == 0:
                    return fn()
                return lambda: fn(self._account)
            elif isinstance(fn, ContractTx):
                return lambda *args: \
                    fn(*[a._account if isinstance(a, Account) else a
                         for a in args],
                       {"from": self._account})
            else:
                import pdb; pdb.set_trace()
                pass
        raise AttributeError


class Currency(object):

    def __init__(self, currency):
        self._currency = currency

    def __getattr__(self, key):
        if hasattr(self._currency, key):
            fn = getattr(self._currency, key)
            if isinstance(fn, ContractCall):
                if len(fn.abi["inputs"]) == 0:
                    return fn()
                return lambda *args: \
                    fn(*[a._account if isinstance(a, Account) else a
                         for a in args])
            elif isinstance(fn, ContractTx):
                raise Error("Must call from an account")
            else:
                import pdb; pdb.set_trace()
                pass
        raise AttributeError


class MkAccounts(object):

    def __init__(self, currency, accounts):
        self._currency = currency
        self._accounts = accounts


    def __getitem__(self, key):
        if isinstance(key, int):
            return Account(self._currency, self._accounts[key])
        raise KeyError(key)


@fixture(autouse=True)
def currency():
    return accounts[0].deploy(ComChainCurrency, "Broutzouf", "Br")


@fixture
def c(currency):
    return Currency(currency)


@fixture
def Accounts(currency):
    return MkAccounts(currency, accounts)


@fixture
def owner(Accounts):
    return Accounts[0]


