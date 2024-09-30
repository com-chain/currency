# -*- coding: utf-8 -*-

from .common import currency, Accounts, c, isolation

from brownie import cccur, accounts, reverts

def test_set_tax(Accounts, c):
    owner = Accounts[0]
    tax_recep = Accounts[1]
    
    # Contract Initial values:
    assert c.getTaxAccount == accounts[0]  
    assert c.getTaxPercent == 0
    assert c.getTaxPercentLeg == 0
    
    # Setup
    owner.setTaxAccount(tax_recep)
    owner.setTaxPercent(13)
    owner.setTaxPercentLeg(17)
    
    # check
    assert c.getTaxAccount == accounts[1]
    assert c.getTaxPercent == 13
    assert c.getTaxPercentLeg == 17
    
    # out of bound
    owner.setTaxPercent(0)
    owner.setTaxPercent(10000)
    with reverts("dev: amount should be greater than 0"):
        owner.setTaxPercent(-1)
    with reverts("dev: amount should be lower than 10000"):
        owner.setTaxPercent(10001)
        
    owner.setTaxPercentLeg(0)
    owner.setTaxPercentLeg(10000)
    with reverts("dev: amount should be greater than 0"):
        owner.setTaxPercentLeg(-1)
    with reverts("dev: amount should be lower than 10000"):
        owner.setTaxPercentLeg(10001)
    
    
def test_pay_nant(Accounts, c):
    owner = Accounts[0]
    john = Accounts[1]
    joe = Accounts[2]

    owner.setAccountParams(john, True, 1, 3000, -1000)
    owner.setAccountParams(joe, True, 1, 3000, -1000)
    owner.pledge(john,10000)
    
    assert c.balanceEL(john) == 10000
    assert c.balanceEL(joe) == 0
    assert c.getTaxPercent==0
    assert c.getTaxPercentLeg==0
    
    john.transfer(joe,3000)
    assert c.balanceEL(john) == 7000
    assert c.balanceEL(joe) == 3000
    assert c.balanceOf(john) == 7000
    assert c.balanceOf(joe) == 3000
    
    


    
def test_pay_nant_tax(Accounts, c):
    owner = Accounts[0]
    tax_recep = Accounts[1]
    john = Accounts[2]
    joe = Accounts[3]
    inc = Accounts[4]
    owner.setTaxAccount(tax_recep)
    owner.setTaxPercent(1300)
    owner.setTaxPercentLeg(1700)
    
    owner.setAccountParams(john, True, 1, 3000, -1000)
    owner.pledge(john,10000)
   
    owner.setAccountParams(joe, True, 0, 3000, -1000)
    assert c.accountType(joe) == 0
    assert c.getTaxPercent == 1300
    
    john.transfer(joe, 3000)
    assert c.balanceEL(john) == 7000
    assert c.balanceEL(joe) == 2610   # = -13%
    assert c.balanceEL(tax_recep) == 390
    
    
    owner.setAccountParams(inc, True, 1, 3000, -1000)    
    john.transfer(inc, 3000)
    assert c.balanceEL(john) == 4000
    assert c.balanceEL(inc) == 2490  # = -17%
    assert c.balanceEL(tax_recep) == 390 + 510



def test_pay_nant_unsuccessfull(Accounts, c):
    owner = Accounts[0]
    john = Accounts[1]
    joe = Accounts[2]

    owner.setAccountParams(john, False, 1, 3000, -1000)
    owner.setAccountParams(joe, True, 1, 3000, -1000)
    with reverts("dev: Source account is locked"):
        john.transfer(joe,3000)
        
    owner.setAccountParams(john, True, 1, 3000, -1000)
    owner.setAccountParams(joe, False, 1, 3000, -1000)
    with reverts("dev: Target account is locked"):
        john.transfer(joe,3000)
        
    owner.setAccountParams(joe, True, 1, 3000, -1000)
    with reverts("dev: Not enough balance"):
        john.transfer(joe,3000)  
          
    owner.pledge(john,10000)
    owner.setContractStatus(False)   
    with reverts("dev: panic lock"):
        john.transfer(joe,3000)  
   
   
    owner.setContractStatus(True)    
    john.transfer(joe,3000) 
   
    assert c.balanceEL(john) == 7000
    assert c.balanceEL(joe) == 3000  
    
    with reverts("dev: overflow and negative check"):
        john.transfer(joe,-1) 
    
    
def test_pay_cm(Accounts, c):
    owner = Accounts[0]
    john = Accounts[1]
    joe = Accounts[2]

    owner.setAccountParams(john, True, 1, 30000, -10000)
    owner.setAccountParams(joe, True, 1, 30000, -10000)

    
    assert c.balanceCM(john) == 0
    assert c.balanceCM(joe) == 0
    assert c.getTaxPercent==0
    assert c.getTaxPercentLeg==0
    
    john.transferCM(joe,3000)
    assert c.balanceCM(john) == -3000
    assert c.balanceCM(joe) == 3000
    assert c.balanceOf(john) == -3000
    assert c.balanceOf(joe) == 3000
    

    
def test_pay_cm_tax(Accounts, c):
    owner = Accounts[0]
    tax_recep = Accounts[1]
    john = Accounts[2]
    joe = Accounts[3]
    inc = Accounts[4]
    owner.setTaxAccount(tax_recep)
    owner.setTaxPercent(1300)
    owner.setTaxPercentLeg(1700)
    
    owner.setAccountParams(john, True, 1, 30000, -10000)
    owner.setAccountParams(joe, True, 0, 30000, -10000)
    assert c.accountType(joe) == 0
    assert c.getTaxPercent == 1300
    
    john.transferCM(joe, 3000)
    assert c.balanceCM(john) == -3000
    assert c.balanceCM(joe) == 2610   # = -13%
    assert c.balanceCM(tax_recep) == 390
    
    
    owner.setAccountParams(inc, True, 1, 30000, -10000)    
    john.transferCM(inc, 3000)
    assert c.balanceCM(john) == -6000
    assert c.balanceCM(inc) == 2490  # = -17%
    assert c.balanceCM(tax_recep) == 390 + 510



def test_pay_cm_unsuccessfull(Accounts, c):
    owner = Accounts[0]
    john = Accounts[1]
    joe = Accounts[2]

    owner.setAccountParams(john, False, 1, 30000, -10000)
    owner.setAccountParams(joe, True, 1, 30000, -10000)
    with reverts("dev: Source account is locked"):
        john.transferCM(joe,3000)
        
    owner.setAccountParams(john, True, 1, 30000, -10000)
    owner.setAccountParams(joe, False, 1, 30000, -10000)
    with reverts("dev: Target account is locked"):
        john.transferCM(joe,3000)
        
    owner.setAccountParams(joe, True, 1, 30000, -10000)
    with reverts("dev: Inferior credit limit hit"):
        john.transferCM(joe,20000)  
   
    owner.setAccountParams(joe, True, 1, 1000, -10000)
    with reverts("dev: Supperior credit limit hit"):
        john.transferCM(joe,10000)       

    owner.setContractStatus(False)   
    with reverts("dev: panic lock"):
        john.transferCM(joe,3000)  
   
   
    owner.setAccountParams(joe, True, 1, 30000, -10000)
    owner.setAccountParams(joe, True, 1, 10000, -10000)
    owner.setContractStatus(True)    
    john.transferCM(joe,10000) 
   
    assert c.balanceCM(john) == -10000
    assert c.balanceCM(joe) == 10000     
    
    with reverts("dev: overflow and negative check"):
        john.transferCM(joe,-1)     


def test_balanceOf(Accounts, c):
    owner = Accounts[0]
    john = Accounts[1]
    joe = Accounts[2]
    owner.setAccountParams(john, True, 0, 30000, -10000)
    owner.setAccountParams(joe, True, 0, 30000, -10000)
    john.transferCM(joe,1000) 
    owner.pledge(joe,100)
    assert  c.balanceCM(joe) == 1000
    assert  c.balanceEL(joe) == 100
    assert  c.balanceOf(joe) == 1100
    
    
