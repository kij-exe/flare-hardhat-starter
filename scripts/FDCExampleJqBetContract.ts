import { artifacts, ethers, run } from "hardhat";
import { BetContractListInstance, BetContractInstance } from "../typechain-types";

const BetContractList = artifacts.require("BetContract");


const FDCHub = artifacts.require("@flarenetwork/flare-periphery-contracts/coston/IFdcHub.sol:IFdcHub");

// Simple hex encoding
function toHex(data) {
    var result = "";
    for (var i = 0; i < data.length; i++) {
        result += data.charCodeAt(i).toString(16);
    }
    return result.padEnd(64, "0");
}

const { JQ_VERIFIER_URL_TESTNET, JQ_API_KEY, VERIFIER_URL_TESTNET, VERIFIER_PUBLIC_API_KEY_TESTNET, DA_LAYER_URL_COSTON } = process.env;

const TX_ID =
    "0xae295f8075754f795142e3238afa132cd32930f871d21ccede22bbe80ae31f73";

// const STAR_WARS_LIST_ADDRESS = "0xD7e76b28152aADC59D8C857a1645Ea1552F7f7fB"; // coston
<<<<<<< HEAD
const STAR_WARS_LIST_ADDRESS = "0x4dF728C77e2944891C44937670fADDA310BFe5C7"; // coston2
=======
// const STAR_WARS_LIST_ADDRESS = "0x4dF728C77e2944891C44937670fADDA310BFe5C7"; // coston2
const STAR_WARS_LIST_ADDRESS = "0xb172c070B9a163775BD67354acd3985c94F52000"; // redeployed on Mykyta's PC on coston

>>>>>>> test1.1

async function deployMainList() {
    const list: BetContractInstance = await BetContractList.new();

    console.log("Char list deployed at:", list.address);
    // verify 
    const result = await run("verify:verify", {
        address: list.address,
        constructorArguments: [],
    })
}

// deployMainList().then((data) => {
//     process.exit(0);
// });


async function prepareRequest() {
    const attestationType = "0x" + toHex("IJsonApi");
    const sourceType = "0x" + toHex("WEB2");
<<<<<<< HEAD
=======

>>>>>>> test1.1
    const requestData = {
        "attestationType": attestationType,
        "sourceId": sourceType,
        "requestBody": {
<<<<<<< HEAD
            "url": "https://api.sportradar.com/soccer/trial/v4/en/schedules/2024-01-06/schedules.json?api_key=8xLd4xboCaPbIMNPZc8WGUze4ypfvxchX275wsIv",
            
            "postprocessJq": `{
             strUid: .schedules[0].sport_event.id,
             score_home_team: .schedules[0].sport_event_status.home_score,
             score_away_team: .schedules[0].sport_event_status.away_score,
             match_status: .schedules[0].sport_event_status.match_status
            }`,
            "abi_signature": `{
                \"components\": [
                    {\"internalType\": \"string\", \"name\": \"strUid\", \"type\": \"string\" },
                    {\"internalType\": \"uint8\", \"name\": \"score_home_team\", \"type\": \"uint8\" },
                    {\"internalType\": \"uint8\", \"name\": \"score_away_team\", \"type\": \"uint8\" },
                    {\"internalType\": \"string\", \"name\": \"match_status\", \"type\": \"string\" }
=======
            "url": "https://raw.githubusercontent.com/kij-exe/flare-hardhat-starter/refs/heads/master/json-examples/match1.json",
            
            "postprocessJq": `{
             strUid: .schedules[0].sport_event.id,
             startTime: .schedules[0].sport_event.start_time,
             home_team: .schedules[0].sport_event.competitors[0].name,
             away_team: .schedules[0].sport_event.competitors[1].name
             }`,
            "abi_signature": `{
                \"components\": [
                    {\"internalType\": \"string\", \"name\": \"strUid\", \"type\": \"string\" },
                    {\"internalType\": \"uint256\", \"name\": \"startTime\", \"type\": \"uint256\" },
                    {\"internalType\": \"string\", \"name\": \"home_team\", \"type\": \"string\" },
                    {\"internalType\": \"string\", \"name\": \"away_team\", \"type\": \"string\" }
>>>>>>> test1.1
                ],
                "name": "SportEvent", "type": "tuple"
            }`
        }
    };

<<<<<<< HEAD

=======
>>>>>>> test1.1
    const response = await fetch(
        `${JQ_VERIFIER_URL_TESTNET}JsonApi/prepareRequest`,
        {
            method: "POST",
            headers: {
                "X-API-KEY": JQ_API_KEY,
                "Content-Type": "application/json",
            },
            body: JSON.stringify(requestData),
        },
    );
    const data = await response.json();
    console.log("Prepared request:", data);
    return data;
}


// prepareRequest().then((data) => {
//     console.log("Prepared request:", data);
//     process.exit(0);
// });

const firstVotingRoundStartTs = 1658423000;//9955;
const votingEpochDurationSeconds = 90;

async function submitRequest() {
    const requestData = await prepareRequest();
<<<<<<< HEAD
=======
    console.log(requestData)
>>>>>>> test1.1

    const starWarsList: BetContractInstance = await BetContractList.at(STAR_WARS_LIST_ADDRESS);


    const fdcHUB = await FDCHub.at(await starWarsList.getFdcHub());

    // Call to the FDC Hub protocol to provide attestation.
    const tx = await fdcHUB.requestAttestation(requestData.abiEncodedRequest, {
        value: ethers.parseEther("1").toString(),
    });
<<<<<<< HEAD
    console.log("Submitted request:", tx.tx);
=======
    // console.log("Submitted request:", tx.tx);
>>>>>>> test1.1

    // Get block number of the block containing contract call
    const blockNumber = tx.blockNumber;
    const block = await ethers.provider.getBlock(blockNumber);

    // Calculate roundId
    const roundId = Math.floor(
        (block!.timestamp - firstVotingRoundStartTs) / votingEpochDurationSeconds,
    );
    console.log(
        `Check round progress at: https://coston-systems-explorer.flare.rocks/voting-epoch/${roundId}?tab=fdc`,
    );
    return roundId;
}

<<<<<<< HEAD
submitRequest().then((data) => {
    console.log("Submitted request:", data);
    process.exit(0);
});


const TARGET_ROUND_ID = 896134; //895847;//895834; // 0
=======
// submitRequest().then((data) => {
//     console.log("Submitted request:", data);
//     process.exit(0);
// });

const TARGET_ROUND_ID = 896421;
>>>>>>> test1.1

async function getProof(roundId: number) {
    const request = await prepareRequest();
    const proofAndData = await fetch(
        `${DA_LAYER_URL_COSTON}fdc/get-proof-round-id-bytes`,
        {
            method: "POST",
            headers: {
                "Content-Type": "application/json",
                // "X-API-KEY": API_KEY,
            },
            body: JSON.stringify({
                votingRoundId: roundId,
                requestBytes: request.abiEncodedRequest,
            }),
        },
    );

    return await proofAndData.json();
}

getProof(TARGET_ROUND_ID)
    .then((data) => {
        console.log("Proof and data:");
        console.log(JSON.stringify(data, undefined, 2));
    })
    .catch((e) => {
        console.error(e);
    });


async function submitProof() {
    const dataAndProof = await getProof(TARGET_ROUND_ID);

    console.log("DATA AND PROOF", dataAndProof);
    const starWarsList = await BetContractList.at(STAR_WARS_LIST_ADDRESS);

    const tx = await starWarsList.createEvent({
        merkleProof: dataAndProof.proof,
        data: dataAndProof.response,
    });
    console.log(tx.tx);
    //console.log(await starWarsList.getAllCharacters());
}


<<<<<<< HEAD
submitProof()
    .then((data) => {
        console.log("Submitted proof");
        process.exit(0);
    })
    .catch((e) => {
        console.error(e);
    });
=======
// submitProof()
//     .then((data) => {
//         console.log("Submitted proof");
//         process.exit(0);
//     })
//     .catch((e) => {
//         console.error(e);
//     });

// async function getRoundId() {

// }
>>>>>>> test1.1
