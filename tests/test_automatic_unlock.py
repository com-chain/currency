# -*- coding: utf-8 -*-

from .common import currency

from brownie import ComChainCurrency, accounts, reverts


def test_pledge(currency):
    assert currency.AutomaticUnlock() is False

    ## Can't pledge towards a non activated account
    with reverts("dev: disabled accounts can't receive pledge"):
        currency.pledge(accounts[1], 100)

    assert currency.balanceOf(accounts[1]) == 0

    currency.setAutomaticUnlock(True)

    ## Can pledge towards a non-activated account
    currency.pledge(accounts[1], 100)

    assert currency.balanceOf(accounts[1]) == 100

    ## can unset
    currency.setAutomaticUnlock(False)

    ## can still pledge for previously used account
    currency.pledge(accounts[1], 100)

    assert currency.balanceOf(accounts[1]) == 200

    ## But can't pledge towards a new non-activated account
    with reverts("dev: disabled accounts can't receive pledge"):
        currency.pledge(accounts[2], 100)

    assert currency.balanceOf(accounts[2]) == 0


