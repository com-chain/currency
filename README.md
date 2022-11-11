# currency

Smart-contract templates for com-chain hosted currency

Those are free and open-source Smartcontracts to run an ethereum token
based currency and barter system.  It was created and by Florian and
Dominique on behalf of Monnaie Leman the Leman Lake Local
Currency. Then maintained and used as templates for the other currency
hosted by Com-Chain (see com-chain.org)

## Features

The smartContracts permit to do :

- Payments
- Reverse Payment
- Automatic approval of reverse payment
- Payement on behalf of an other user

Account management includes:

- Account activation/inactivation
- Changing account type
- Setting barter limits
- Sending initial monney

## Configuration

- If you are planning to use the contract withing the Com-Chain
  framework, you must keep the function signature.

- Unused function can have their body replaced by a revert() statment.

- You should choose in the pledge function between two check: one is
  checking for overflow, the second also check for non-negative
  pledge.

## Our Philosophy

- Empower the people: Give people the ability to interact with the
  Ethereum blockchain easily, without having to run a full node.

- Make it easy & free: Everyone should be able to create a wallet and
  send Tokens without additional cost.  People are the Priority:
  People are the most important.

- If it can be hacked, it will be hacked: Never save, store, or
  transmit secret info, like passwords or keys. Open source &
  auditable.

## Contact

If you can think of any other features or run into bugs, let us
know. You can drop a line at it {at} monnaie {-} leman dot org.
