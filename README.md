# Supercartd

![home](/docs/sc%20home.PNG)


Supercartd is an MVP of a multichain ecommerce store. You can login using an [Internet Identity](https://internetcomputer.org/internet-identity) and create your own basic ecommerce storefront and accept payments in tokens across various chains.

This tech demo was created to see what was possible with the [Internet Computer](https://internetcomputer.org/) using stable storage and https outcalls. The overall goal is to explore decentralized ecommerce using general purpose public blockchains for speed and efficiency. The platform uses open RPC nodes and oracle services to confirm transactions and has no other dependencies other than ICP / Cycles.

**THIS IS BETA SOFTWARE - THE CODE HAS NOT BEEN AUDITED**

Supercartd offers:

    Simple merchant onboarding (just login with an Internet Identity)    
    Free storefront (create your own ecommerce shop)
    Multichain token pricing engine (transparent price feeds and sources)
    Free simple checkout (to send your customers to)

This platfrom was built with [Svelte](https://svelte.dev) and [Motoko](https://internetcomputer.org/docs/current/motoko/main/motoko).

# Build Requirements

``dfx version 0.17+``
[https://internetcomputer.org/docs/current/developer-docs/getting-started/install/](https://internetcomputer.org/docs/current/developer-docs/getting-started/install)

``mops``
[https://mops.one/](https://mops.one/)

``node / npm``
[https://docs.npmjs.com/downloading-and-installing-node-js-and-npm](https://docs.npmjs.com/downloading-and-installing-node-js-and-npm)



# Instructions

## Building locally

- download repo
- cd into /src/frontend
- ``npm install``
- cd into ./
- ``mops install``
- open new terminal window and start the local chain with ``dfx start``
- ``dfx deploy`` in the main window should install all canisters and build the front end
- ``npm run dev`` to start the svelte front end
- access the app via https://localhost:5173

## Accessing the admin

- navigate to https://localhost:5173 and click ``login`` 
- you will be redirected to the [Internet Identity](https://internetcomputer.org/internet-identity) webauthn login
- create or use an existing identity
- you will be redirected to the admin page where you being your checkout setup

### 1) Checkout Setup

- create a checkout to get started, add a name and optional email and phone for notifications
- *notifications are not working at this time*
- enable the checkout
- save the checkout

### 2) Catalog Setup

- add a new product
- edit required fields
- enable the product
- save the product
- repeat above steps for however many products you wish to list 


### 3) Payments Setup

- select which payment method you want to accept
- edit the method and add your wallet info
- save the method

## Accessing the Public Checkout

![home](/docs/checkout%20ready.PNG)


- if all 3 steps above are completed and the checkout is ``enabled`` you should see a link to go to the public page
- test the public checkout by adding items to your cart and continuing the checkout
- do a test order with sepolia ETH and receive a receipt


## Configuration

- If you decide to use walletconnect, you need to have a walletconnect project id that is added to .env in the /src/frontend folder 
- VITE_WALLETCONNECT_PROJECT_ID="``your_walletconnect_project_id``"
- SOL integration is set to work with [Alchemy](https://www.alchemy.com/) 
- VITE_ALCHEMY_SOL_KEY="``your_alchemy_sol_project_id``"


# Known Limitations

### Tokens

- The platform supports a small subset of tokens which are hardcoded into the TokenFactory. If you wish to add your own custom tokens, you need to add them directly to the TokenFactory. Additionally, please ensure you add relevant mappings to the PriceFactory so your added token can fetch prices from remote sources.

### Prices

- As of [3/4/2024] pricing is being pulled from a custom Supercart netlify function as the [EVM canister](https://internetcomputer.org/docs/current/developer-docs/multi-chain/ethereum/evm-rpc) was just released and didn't make this version. I'll work to continue making the pricing engine more robust and transparent including using the [Exchange Rate canister](https://internetcomputer.org/docs/current/developer-docs/defi/exchange-rate-canister).

- This version has support for calling chainlink directly via public RPCs to get onchain pricing. It also tries to fetch from CoinGecko and a few other services

### Chains
- ETH sepolia - working tested
- ICP mainnet - working tested (icp only, icrc1 is not working)
- SOL mainnet - working tested (sol only, spl tokens not tested)

# Security
- **Supercartd does not store tokens, private keys or take custody of funds.** 
- The platform is non-custodial and relies on clients generating hash receipts from transactions they send. 
- The receipts are verified optimistically and future versions will include more configuration around # of confirmations and finality per chain.

# Design Philosphy

- Create an ecommerce platform where merchants can be in 100% control of their data and offer customers a simple and fast checkout
- Remove as many possible points of failure and 3rd party dependencies invovled in online commerce
- Build something end-users would like to use, thats appealing, fast and reliable 
- Avoid storing any sensitive data, tracking or invasive cookies
- Use hardcoded values for known contracts, tokens and endpoints to minimize user input data errors
- Use public, well known, reliable RPCs for transactions and rely on client wallets/biometrics for end user security
- Utilize the best aspects of the Internet Computer such as fast finality, cheap transactions and native multichain to do most of the heavy lifting
- Use and support the most common wallets and connectors and minimize overall trust assumptions

# Demos

![Demo 1](/docs/scdemo1.gif)

![Demo 2](/docs/scdemo2.gif)

![Demo 3](/docs/scdemo3.PNG)