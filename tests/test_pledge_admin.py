# -*- coding: utf-8 -*-

from .common import currency

from brownie import ComChainCurrency, accounts, reverts




def test_pledge(currency):

    owner = accounts[0]
    john = accounts[1]

    ## make john have roles that are not allowed to pledge
    for t in [0, 1, 4]:
        currency.setAccountParams(john, True, t, -1000, 3000)

        ## Do not have permission to pledge
        with reverts("dev: permission denied"):
            currency.pledge(owner, 100, {"from": john})

        assert currency.balanceOf(owner) == 0

    s = 0
    ## make john have roles that are allowed to pledge
    for t in [2, 3]:
        ## make john pledge
        currency.setAccountParams(john, True, t, -1000, 3000)

        currency.pledge(owner, 100, {"from": john})
        s += 100

        assert currency.balanceOf(owner) == s

    ## total amount pledged
    assert currency.amountPledged() == s

    ## Make john a disabled pledge admin
    currency.setAccountParams(john, False, 3, -1000, 3000)
    with reverts("dev: disabled accounts can't pledge"):
        currency.pledge(owner, 100, {"from": john})

    ## Make john a enabled pledge admin
    currency.setAccountParams(john, True, 3, -1000, 3000)
    walter = accounts[2]
    with reverts("dev: disabled accounts can't receive pledge"):
        currency.pledge(walter, 100, {"from": john})

    ## total amount pledged
    assert currency.amountPledged() == s


def test_set_account_param(currency):

    owner = accounts[0]
    john = accounts[1]
    walter = accounts[2]

    ## make john a pledge admin
    currency.setAccountParams(john, True, 3, -1000, 3000)

    ## john as a pledge admin can't setAccountParams

    for t in range(0, 5):
        for a in [True, False]:
            for u in [owner, john, walter]:
                with reverts("dev: permission denied"):
                    currency.setAccountParams(u, a, t, -1000, 3000, {"from": john})

