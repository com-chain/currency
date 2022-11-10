# -*- coding: utf-8 -*-

from pytest import fixture

from brownie import ComChainCurrency, accounts, reverts


@fixture
def currency():
    return accounts[0].deploy(ComChainCurrency, "Broutzouf", "Br")

