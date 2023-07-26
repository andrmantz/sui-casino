# SUI 2-sided gambling casino

### DISCLAIMER
The project was created for fun as a side hustle. The soundness of the protocol has not been proved, many risks have not been mitigated and currently it is both untested and unaudited. DO NOT USE AT A PRODUTION ENVIRONMENT.

### Description

The project aims to provide a fun 2-sided gambling casino. On the one hand, there are the casino players, who can play at the lottery and earn coins based on the amount of numbers they guess correctly. On the other hand, there are the liquidity providers, who can provide their tokens and gain shares on single-asset vauls, which will be used to pay rewards.

#### What does 2-sided mean?

- Every time a casino player wins and earns coins, the vault's underlying token balance will decrease and LPs' shares are decreasing.
- Every time a casino player loses, the vault's underlying token balance will increase and LPs' shares are increasing.

#### Coins supported

Anyone can add support for a new coin, as vaults are created dynamically when liquidity of a new coin is added. It's important to note that the first 1000 tokens are used as dust, in order to avoid inflation attacks up to a certain point.

#### Randomness source

The current round time is one Sui epoch - 1 day at the time of writing. This means that any lottery bets will be available for redeem from the next epoch forward. In order to fulfill the randomness, the lucky number should be posted in the smart contract via an off-chain oracle. The function `oracle::set_lucky_number` is provided for that reason. The function must be called **after** the new epoch has started.

### Roles

#### Liquidity provider

Liquidity providers can add their coins to existing vaults or create new ones and get shares over them. Their returns depend on the casino games, as they earn coins while gamblers lose and vice versa. The following functions are provided:
- `add_liquidity<X>`: Add liquidity for `Coin<X>` in the relative vault and gain `Coin<LP<X>>` in return.
- `remove_liquidity<X>`:  Remove liquidity, by sending `Coin<LP<X>>` to the vault and receiving `Coin<X>` in return.


#### Casino player

Casino players can bet any supported coin in the lottery. By supported coin we refer to any coin there's the respective vault in the casino.

- `place_bet<X>`: Place a new bew of  `Coin<X>`. The winnings will be on the same coin as the bet. A `Ticket<X>` is transferred to the caller, which will be later used to redeem the bet.
- `redeem_bet<X>`: Send back the `Ticket` and get the winnings.
- `cancel_bet<X>`: Can be used to cancel the bet early. Half of the input amount is returned.

#### Admin

Admin is responsible for the proper function of the smart contracts. In case the contract is ever deployed in production, this address should be a multisig, and even protected by timelock as it has great power. The functions that require admin authorization are the following:
- `pause`: Pauses the contract in case of emergency. The only entry function that can be called while the contract is paused is the `remove_liquidity`, to mitigate centralization risks up to a certain level.
- `unpause`: Resumes the contract.
- `modify_admin`: Transfers the admin role to another address.
- `modify_oracle`: Changes the address of the oracle. IMPORTANT: This is a huge risk, as a malicious admin could change the oracle address, in order to manipulate the lucky number and steal users funds.

#### Oracle

The oracle is responsible to provide the lucky numbers selected in the smart contract. It does so via the `set_lucky_number` function.

### Risks

- Liquidity providers can withdraw their shares right after bets are placed, or even frontrun the oracle, and get away with extra coins, while casino players are not able to earn any as bets are not yet finalized. I may or may not mitigate this vulnerability in the future. A possible solution would be to timelock the LPs coins, but doesn't completely patch the vulnerability.
- Vaults may lack liquidity in a way that players cannot redeem their earnings, so end up losing coins. The values returned by the `get_multiplier` function are random.
- Inflation attack in `add_liquidity` has not been fully mitigated and it's still possible as a sort of griefing.
- The test coverage is minimal, thus there could be a number of uncaught bugs. I plan to add tests and verify the correctness in the short term.
- Centralization risk, both by the admin and by the oracle roles.