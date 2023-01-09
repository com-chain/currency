# -*- coding: utf-8 -*-

from .common import currency

from brownie import cccur, accounts, reverts


def test_set_account_param(currency):

    owner = accounts[0]
    john = accounts[1]
    walter = accounts[2]

    ## make john have roles that are not allowed to setAccountsParams
    for john_role in [0, 1, 3]:
        currency.setAccountParams(john, True, john_role, -1000, 3000)

        ## Do not have permission to setAccountParams
        for t in range(0, 5):
            for a in [True, False]:
                for u in [owner, john, walter]:
                    with reverts("dev: permission denied"):
                        currency.setAccountParams(u, a, t, -1000, 3000, {"from": john})


    ## make john have roles that are allowed to setAccountParams
    for john_role in [2, 4]:
        currency.setAccountParams(john, True, john_role, -1000, 3000)

        ## Can setAccountParams without restrictions
        for t in range(0, 5):
            for a in [True, False]:
                currency.setAccountParams(walter, a, t, -1000, 3000, {"from": john})

    ## Make john a disabled property admin
    currency.setAccountParams(john, False, 4, -1000, 3000)

    ## Do not have permission to setAccountParams
    for t in range(0, 5):
        for a in [True, False]:
            with reverts("dev: disabled accounts can't set account params"):
                currency.setAccountParams(walter, a, t, -1000, 3000, {"from": john})


