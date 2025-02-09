## Decentralised FDC-based betting platform (prediction market built on flare network)

## Motivation:
Prediction market such as polymarket, Gnosis is on a trends however, the the transactions executed on these betting markets can have some risks. Flare network provide a trustless API usage which allows web2 data to be processed on-chain. Such an architecture will innovate the state of the prediction market. 

## Project Detail:
The project will first take a data by using API provided by sporttrader(link: https://developer.sportradar.com/). Then the json formatted data will be processed and will invoke a function that will create a market on flare network. Users will place bets in a market and the money used will be stored on a liquidity pool. The program will call API request at regular interval and will identify whether an event is ended or not. When the event is finished then the market will automatically be closed.  
The project intends to convert a web2 information into a data in which we can use it on-chain and will determine the 

**IMPORTANT!!**
The supporting library uses Openzeppelin version `4.9.3`, be careful to use the documentation and examples from that library version.

### Getting started

If you are new to Hardhat please check the [Hardhat getting started doc](https://hardhat.org/hardhat-runner/docs/getting-started#overview)

1. Clone and install dependencies:

   ```console
   git clone https://github.com/flare-foundation/flare-hardhat-starter.git
   cd flare-hardhat-starter
   ```

   and then run:

   ```console
   yarn
   ```

   or

   ```console
   npm install
   ```

2. Set up `.env` file

   ```console
   mv .env.example .env
   ```

3. Change the `PRIVATE_KEY` in the `.env` file to yours

4. Compile the project

    ```console
    yarn hardhat compile
    ```

    or

    ```console
    npx hardhat compile
    ```

    This will compile all `.sol` files in your `/contracts` folder. It will also generate artifacts that will be needed for testing. Contracts `Imports.sol` import MockContracts and Flare related mocks, thus enabling mocking of the contracts from typescript.

5. Run Tests

    ```console
    yarn hardhat test
    ```

    or

    ```console
    npx hardhat test
    ```

6. Deploy

    Check the `hardhat.config.ts` file, where you define which networks you want to interact with. Flare mainnet & test network details are already added in that file.

    Make sure that you have added API Keys in the `.env` file

   ```console
   npx hardhat run scripts/tryDeployment.ts
   ```

## Resources

- [Flare Developer Hub](https://dev.flare.network/)
- [Hardhat Docs](https://hardhat.org/docs)

