# -*- coding: utf-8 -*-

from .common import currency, Accounts, c

from brownie import reverts


def test_automatic_unlock_base(Accounts, c):

    assert c.automaticUnlock is False

    owner = Accounts[0]
    john = Accounts[1]
    bob = Accounts[2]
    

    ## Can't pledge towards a non activated account
    with reverts("dev: disabled accounts can't receive pledge"):
        owner.pledge(john, 100)

    assert c.balanceOf(john) == 0

    owner.setAutomaticUnlock(True)

    ## Can pledge towards a non-activated account
    owner.pledge(john, 100)

    assert c.balanceOf(john) == 100

    ## can unset
    owner.setAutomaticUnlock(False)

    ## can still pledge for previously used account
    owner.pledge(john, 100)

    assert c.balanceOf(john) == 200

    ## But can't pledge towards a new non-activated account
    with reverts("dev: disabled accounts can't receive pledge"):
        owner.pledge(bob, 100)

    assert c.balanceOf(bob) == 0
    
    assert owner._account.balance()==100000000000000000000  # Show that gaz is not consumed during transaction...

def test_automatic_unlock_permission(Accounts, c):

    assert c.automaticUnlock is False

    owner = Accounts[0]
    john = Accounts[1]

    ## Can't pledge towards a non activated account
    with reverts("dev: require to be owner"):
        john.setAutomaticUnlock(True)

