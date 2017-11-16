# Stox Smart Contracts v0.1 (alpha)

Stox is a blockchain prediction markets platform. To learn more about Stox please visit the Stox [website](https://www.stox.com/) and read the Stox [whitepaper] (https://www.stox.com/assets/pdf/stox-whitepaper.pdf)

## Contacts Overview

Our first smart contracts are being released with a Pool Event. A Pool Event distributes tokens between all winners according to their proportional investment in the winning outcome. The event winning outcome is decided by an oracle contract.

## Pool Event

### Pool Event Example

An event has 3 different outcomes:
1. Outcome 1
2. Outcome 2
3. Outcome 3
 
User A placed 100 tokens on Outcome 1

User B placed 300 tokens on Outcome 1

User C placed 100 tokens on Outcome 2

User D placed 100 tokens on Outcome 3
 
Total token pool: 600
 
For example, after the event ends, the oracle decides the winning outcome is Outcome 1.
 
Users can now withdraw the following token amount: from their predictions: 
 
User A -> 150 tokens (100 / (100 + 300) * 600)

User B -> 450 tokens (300 / (100 + 300) * 600)

User C -> 0 tokens

User D -> 0 tokens


### Pool Event Lifecycle

* **Initializing** - The status when the event is first created. During this stage we define the event outcomes.
* **Published** - The event is published and users can now predict on the different outcomes.
* **Resolved** - The event is resolved and users can withdraw their winnings.
* **Paused** - The event is paused and users can no longer make predictions until the event is published again.
* **Canceled** - The event is canceled. Users can get their STX refunded to them.
