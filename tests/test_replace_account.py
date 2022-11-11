# -*- coding: utf-8 -*-

from .common import currency, Accounts

from brownie import ComChainCurrency, accounts, reverts


def test_replace_account_standard(Accounts):

    owner = Accounts[0]
    john1 = Accounts[1]
    john2 = Accounts[2]

    owner.setAccountParams(john1, True, 1, -1000, 3000)
    owner.pledge(john1, 100)

    john1.allowReplaceBy(john2)
    john2.acceptReplaceAccount()

    assert john1.accountType() == 1
    assert john2.accountType() == 1

    assert john2.balanceOf() == 100
    assert john1.balanceOf() == 0

    assert john1.accountStatus() is False
    assert john2.accountStatus() is True

    assert john1.limitCredit() == 0
    assert john2.limitCredit() == 3000

    assert john1.limitDebit() == 0
    assert john2.limitDebit() == -1000


# def test_replace_account_highjack(Accounts):

#     owner = Accounts[0]
#     john1 = Accounts[1]
#     john2 = Accounts[2]
#     walter = Accounts[3]

#     owner.setAccountParams(john1, True, 2, -1000, 3000)
#     owner.setAccountParams(walter, True, 0, -500, 1000)
#     owner.pledge(john1, 100)

#     john1.allowReplaceBy(john2)
#     ## highjack attempt
#     walter.allowReplaceBy(john2)

#     john2.acceptReplaceAccount()

#     assert john1.accountType() == 2
#     assert john2.accountType() == 2

#     assert john2.balanceOf() == 100
#     assert john1.balanceOf() == 0

#     assert john1.accountStatus() is False
#     assert john2.accountStatus() is True

#     assert john1.limitCredit() == 0
#     assert john2.limitCredit() == 3000

#     assert john1.limitDebit() == 0
#     assert john2.limitDebit() == -1000


def test_replace_account_to_non_new_account(Accounts):

    owner = Accounts[0]
    john1 = Accounts[1]
    john2 = Accounts[2]
    walter = Accounts[3]

    owner.setAccountParams(john1, True, 1, -1000, 3000)
    owner.pledge(john1, 100)

    with reverts("dev: only new account can be target of a replacement"):
        john1.allowReplaceBy(owner)

    owner.setAccountParams(walter, True, 0, -1000, 3000)
    with reverts("dev: only new account can be target of a replacement"):
        john1.allowReplaceBy(walter)

    john1.allowReplaceBy(john2)



def test_replaced_account_not_usable(Accounts):

    owner = Accounts[0]
    john1 = Accounts[1]
    john2 = Accounts[2]
    walter = Accounts[3]

    owner.setAccountParams(john1, True, 1, -1000, 3000)
    owner.pledge(john1, 100)

    john1.allowReplaceBy(john2)
    john2.acceptReplaceAccount()

    ## Can't set properties of a replaced account
    with reverts("dev: replaced account cannot be modified"):
        owner.setAccountParams(john1, True, 1, -1000, 3000)
