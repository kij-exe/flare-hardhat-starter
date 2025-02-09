// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;

import {ContractRegistry} from "@flarenetwork/flare-periphery-contracts/coston/ContractRegistry.sol";

// Dummy import to get artifacts for IFDCHub
import {IFdcHub} from "@flarenetwork/flare-periphery-contracts/coston/IFdcHub.sol";
import {IFdcRequestFeeConfigurations} from "@flarenetwork/flare-periphery-contracts/coston/IFdcRequestFeeConfigurations.sol";

import {IJsonApiVerification} from "@flarenetwork/flare-periphery-contracts/coston/IJsonApiVerification.sol";
import {IJsonApi} from "@flarenetwork/flare-periphery-contracts/coston/IJsonApi.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract BetContract is Ownable {
    using SafeERC20 for IERC20;

    uint256 public constant DAY = 86400;
    uint256 public constant MULTIPLIER_FACTOR = 1000;

    IERC20 public immutable TOKEN;

    // max bet is 100 songbird / flare
    uint256 public maxBet;
    uint256 public betId = 0;
    bool public isProduction = true;
    address public public_owner; // for tests

    // IMatchResultVerification public immutable VERIFICATION;

    /**
     * @dev Mapping of addresses that are authorized to add mint new tokens.
     */
    mapping (address => bool) public authorizedAddresses;

    /**
     * @dev Only authorized addresses can call a function with this modifier.
     */
    modifier onlyAuthorized() {
        // require(authorizedAddresses[msg.sender] || owner() == msg.sender, "Not authorized");
        // temporarily authorize everybody
        _;
    }

    constructor(
        IERC20 _token
        //address _verification
    ) {
        maxBet = 1000 ether;
        TOKEN = _token;
        public_owner = owner(); // for tests
        //VERIFICATION = IMatchResultVerification(_verification);
    }
    
    function isJsonApiProofValid(
        IJsonApi.Proof calldata _proof
    ) public view returns (bool) {
        // Inline the check for now until we have an official contract deployed
        return
            ContractRegistry.auxiliaryGetIJsonApiVerification().verifyJsonApi(
                _proof
            );
    }

    struct Event {
        uint256 uid;
        string home_team;
        string away_team;
        uint256 startTime;
        uint256 poolAmount;
        uint16 winner;
        //bool cancelled;
        Choices[] choices;
    }

    struct EventTransportObject1 {
        string strUid;
        uint256 startTime;
        string home_team;
        string away_team;
    }
    
    struct EventTransportObject2 {
        string strUid;
        uint8 score_home_team;
        uint8 score_away_team;
        string match_status;
    }

    struct Choices {
        uint16 choiceId;
        string choiceName;
        uint256 totalBetsAmount;
        uint256 currentMultiplier;
    }

    struct Bet {
        uint256 id;
        uint256 eventUID;
        address bettor;
        uint256 betAmount;
        uint256 winMultiplier;
        uint256 betTimestamp;
        uint16 betChoice;
        bool claimed;
    }

    mapping(uint256 => Event) public events;
    //mapping(uint256 => bool) public eventRefund; // is event in refund state
    //mapping(Sports => uint256[]) public sportEventsBySport;
    //mapping(uint256 => mapping(Sports => uint256[]))
    //    public sportEventsByDateAndSport;
    mapping(uint256 => uint256[]) public eventsByDate;
    mapping(uint256 => uint256[]) public betsByEventStartDate;
    mapping(uint256 => mapping(address => uint256[])) public betsByDateAndUser;
    mapping(uint256 => uint256[]) public betsByEvent;
    mapping(address => uint256[]) public betsByUser;
    mapping(uint256 => Bet) public betById;

    event EventCreated(uint256 uid, string home_time, string away_team, uint256 startTime);

    event BetPlaced(
        uint256 id,
        uint256 eventUID,
        address bettor,
        uint256 amount,
        uint16 choice
    );

    event BetSettled(uint256 eventUID, uint32 winner, uint256 winMultiplier);
    
    //event BetRefunded(uint256 eventUID);
    
    function createEvent(
        IJsonApi.Proof calldata data
    ) external onlyAuthorized() {
        require(isJsonApiProofValid(data), "Invalid proof");
        EventTransportObject1 memory dto = abi.decode(
            data.data.responseBody.abi_encoded_data,
            (EventTransportObject1)
        );

        _createEvent(
            dto.home_team,
            dto.away_team,
            dto.startTime,
            ["home_team", "draw", "away_team"],
            [333, 334, 333],
            1000,
            stringToUint256(dto.strUid)
        );
    }

function _createEvent(
        string memory home_team,
        string memory away_team,
        uint256 startTime,
        string[3] memory choices,
        uint16[3] memory initialVotes,
        uint256 initialPool,
        uint256 uid
    ) internal {
        // uint256 uid = generateUID(startTime, home_team, away_team);
        // require(uid == _uid, "UID mismatch");
        require(events[uid].uid == 0, "Event already exists");

        require(
            choices.length == initialVotes.length, 
            "choices & initialVotes length mismatch"
        );
        require( // can be changed later
            choices.length == 2 || choices.length == 3,
            "choices length has to be 2 or 3"
        );
        Event storage ev = events[uid];
        ev.uid = uid;
        //ev.title = title;
        ev.home_team = home_team;
        ev.away_team = away_team;

        ev.poolAmount = initialPool;
        ev.startTime = startTime;
        //ev.cancelled = false;

        uint256 sumVotes;
        for (uint256 i = 0; i < initialVotes.length; i++) {
            sumVotes += initialVotes[i];
        }

        uint256 initialBetAmount;
        for (uint256 i = 0; i < choices.length; i++) {
            initialBetAmount = calculateInitialBetAmount(initialPool, sumVotes, initialVotes[i]);
            ev.choices.push(
                Choices({
                    choiceId: uint16(i + 1),
                    choiceName: choices[i],
                    totalBetsAmount: initialBetAmount,
                    currentMultiplier: calculateMultiplier(initialBetAmount, initialPool)
                })
            );
        }

        //sportEventsBySport[sport].push(ev.uid);
        //sportEventsByDateAndSport[roundTimestampToDay(ev.startTime)][sport].push(ev.uid);
        eventsByDate[roundTimestampToDay(ev.startTime)].push(ev.uid);

        if (initialPool > 0) {
            TOKEN.safeTransferFrom(
                msg.sender, 
                address(this), //address of the contract
                initialPool
            );
        }

        emit EventCreated(uid, ev.home_team, ev.away_team, ev.startTime);
    }

    // function generateUID(
    //     uint256 startTime,
    //     string memory home_team,
    //     string memory away_team
    // ) public pure returns (uint256) {
    //     return keccak256(abi.encode(startTime, home_team, away_team));
    // }

    function calculateInitialBetAmount(
        uint256 initialPool,
        uint256 sumOfVotes,
        uint256 choiceVotes
    ) private pure returns (uint256) {
        return initialPool * choiceVotes / sumOfVotes ;
    }

    function calculateMultiplier(
        uint256 totalChoiceAmount,
        uint256 totalPoolAmount
    ) private pure returns (uint256) {
        uint8 adjustmentFactor = 101;
        require(totalPoolAmount > 0, "Pool amount must be greater than 0");
        require(totalChoiceAmount > 0, "Choice amount must be greater than 0");
        require(
            totalPoolAmount >= totalChoiceAmount,
            "Pool amount must be greater than choice amount"
        );
        // the multipiler is a factor of 1000
        uint256 multiplier = totalPoolAmount * MULTIPLIER_FACTOR * 100 / adjustmentFactor / totalChoiceAmount;
        // new total choice amount cannot be bigger than the total pool amount
        return multiplier;
    }

    //function cancelSportEvent(uint256 _uid) external onlyAuthorized() {
    //    Event storage ev = events[_uid];
    //    require(ev.uid != 0, "Event does not exist");
    //    require(ev.winner == 0, "Result already drawn");
    //    ev.cancelled = true;
    //}

    // function getEventFromUID(uint256 uid) external view returns (Event memory) {
    //     return events[uid];
    // }

    // function getEventsByDate(
    //     uint256 date
    // ) external view returns (Event[] memory) {
    //     uint256 len = eventsByDate[date].length;
    //     Event[] memory _events = new Event[](len);
    //     
    //     for (uint256 i = 0; i < len; i++) {
    //         _events[i] = events[eventsByDate[date][i]];
    //     }
    //     return _events;
    // }

    function placeBet(uint256 eventUID, uint16 choice, uint256 amount) external {
        require(amount <= maxBet, "Bet amount exceeds max bet");
        require(amount > 0, "Bet amount must be greater than 0");

        Event storage currentEvent = events[eventUID];
        require(currentEvent.uid != 0, "Event does not exist");
        //require(!eventRefund[currentEvent.uid], "Event in refund state");
        //require(!currentEvent.cancelled, "Event cancelled");
        require(
            currentEvent.startTime > block.timestamp,
            "Event already started"
        );
        require(
            choice < currentEvent.choices.length,
            "Invalid choice"
        );

        betId++;

        // Transfer bet amount
        TOKEN.safeTransferFrom(
            msg.sender, 
            address(this), 
            amount
        );

        // for the multiplier, we first need to add the amount to the pool, and add to the total bets ammount for the choice
        currentEvent.poolAmount += amount;
        uint256 multiplier = calculateMultiplier(
            currentEvent.choices[choice].totalBetsAmount + amount,
            currentEvent.poolAmount
        );

        Bet memory bet = Bet({
            id: betId,
            eventUID: eventUID,
            bettor: msg.sender,
            betAmount: amount,
            winMultiplier: multiplier,
            betTimestamp: block.timestamp,
            betChoice: choice,
            claimed: false
        });

        // choice amount is multiplied
        uint256 totalChoiceAmount = currentEvent.choices[choice].totalBetsAmount +
            (amount * multiplier / MULTIPLIER_FACTOR);

        require(
            totalChoiceAmount <= currentEvent.poolAmount,
            "Total bets amount exceeds pool amount"
        );
        currentEvent.choices[choice].totalBetsAmount = totalChoiceAmount;

        uint256 dayStart = roundTimestampToDay(currentEvent.startTime);
        
        // recalculate choices
        for (uint256 i = 0; i < currentEvent.choices.length; i++) {
            currentEvent.choices[i].currentMultiplier = calculateMultiplier(
                currentEvent.choices[i].totalBetsAmount,
                currentEvent.poolAmount
            );
        }

        betsByUser[msg.sender].push(bet.id);
        betsByEventStartDate[dayStart].push(bet.id);
        betsByDateAndUser[dayStart][msg.sender].push(bet.id);

        betsByEvent[eventUID].push(bet.id);
        betById[bet.id] = bet;

        emit BetPlaced(bet.id, eventUID, msg.sender, amount, choice);
    }

    function claimWinnings(uint256 _betId) external {
        Bet storage bet = betById[_betId];
        require(bet.winMultiplier > 0, "Invalid betId");
        require(bet.bettor == msg.sender, "You are not the bettor");
        Event memory _event = events[bet.eventUID];
        require(_event.uid != 0, "Event does not exist");
        require(_event.winner > 0, "Result not drawn");
        //require(!eventRefund[sportEvent.uid], "Event in refund state");
        //require(!_event.cancelled, "Event cancelled");

        require(
            _event.winner == _event.choices[bet.betChoice].choiceId, 
            "Not winner"
        );
        require(!bet.claimed, "Winnings already claimed");

        bet.claimed = true;
        uint256 winnings = bet.betAmount * bet.winMultiplier / MULTIPLIER_FACTOR;

        TOKEN.safeTransfer(
            msg.sender, 
            winnings
        );

        emit BetSettled(
            bet.eventUID,
            events[bet.eventUID].winner,
            bet.winMultiplier
        );
    }

    //function refund(uint256 _betId) external {
    //    Bet storage bet = betById[_betId];
    //    require(bet.winMultiplier > 0, "Invalid betId");
    //    require(bet.bettor == msg.sender, "You are not the bettor");
    //    SportEvent memory sportEvent = sportEvents[bet.eventUID];
    //    require(sportEvent.uid != 0, "Event does not exist");
    //    require(sportEvent.winner == 0, "Result already drawn");
    //
    //    require(!bet.claimed, "Refund already claimed");
    //
    //    require(
    //        sportEvent.cancelled || sportEvent.startTime + DAY * 14 < block.timestamp,
    //        "Refund only for cancelled or 14 days after event startTime (if winner not set)"
    //    );
    //
    //    bet.claimed = true;
    //    eventRefund[sportEvent.uid] = true;
    //
    //    TOKEN.safeTransfer(
    //        msg.sender, 
    //        bet.betAmount
    //    );
    //
    //    emit BetRefunded(bet.eventUID);
    //}

    /**
     * @dev Events specific choice data
     */
    function getEventChoiceData(uint256 uid, uint32 _choice) external view returns (Choices memory) {
        return events[uid].choices[_choice];
    }

    /**
     * @dev Events by uids
     */
    function getEvents(uint256[] memory uids) external view returns (Event[] memory) {
        Event[] memory _events = new Event[](uids.length);
        
        for (uint256 i = 0; i < uids.length; i++) {
            _events[i] = events[uids[i]];
        }
        return _events;
    }

    /**
     * @dev Events by sport
     */
    //function getSportEventsBySportFromTo(Sports sport, uint256 from, uint256 to) public view returns (SportEvent[] memory) {
    //    uint256 cnt = to - from;
    //    SportEvent[] memory events = new SportEvent[](cnt);
    //    for (uint256 i = 0; i < cnt; i++) {
    //        events[i] = sportEvents[sportEventsBySport[sport][from + i]];
    //    }
    //    return events;
    //}

    //function getSportEventsBySport(Sports sport) external view returns (SportEvent[] memory) {
    //    return getSportEventsBySportFromTo(sport, 0, sportEventsBySport[sport].length);
    //}

    //function sportEventsBySportLength(Sports sport) external view returns (uint256) {
    //    return sportEventsBySport[sport].length;
    //}

    /**
     * @dev Bets by event
     */
    function getBetsByEvent(uint256 uid) external view returns (Bet[] memory) {
        Bet[] memory bets = new Bet[](betsByEvent[uid].length);
        for (uint256 i = 0; i < betsByEvent[uid].length; i++) {
            bets[i] = betById[betsByEvent[uid][i]];
        }
        return bets;
    }

    /**
     * @dev Bets by date
     */
    function getBetsByDateFromTo(uint256 date, uint256 from, uint256 to) public view returns (Bet[] memory) {
        uint256 cnt = to - from;
        Bet[] memory bets = new Bet[](cnt);
        for (uint256 i = 0; i < cnt; i++) {
            bets[i] = betById[betsByEventStartDate[date][from + i]];
        }
        return bets;
    }

    function getBetsByDate(uint256 date) external view returns (Bet[] memory) {
        return getBetsByDateFromTo(date, 0, betsByEventStartDate[date].length);
    }

    function betsByEventStartDateLength(uint256 date) external view returns (uint256) {
        return betsByEventStartDate[date].length;
    }

    /**
     * @dev Bets by user
     */
    function getBetsByUserFromTo(address user, uint256 from, uint256 to) public view returns (Bet[] memory) {
        uint256 cnt = to - from;
        Bet[] memory bets = new Bet[](cnt);
        for (uint256 i = 0; i < cnt; i++) {
            bets[i] = betById[betsByUser[user][from + i]];
        }
        return bets;
    }

    function getBetsByUser(address user) external view returns (Bet[] memory) {
        return getBetsByUserFromTo(user, 0, betsByUser[user].length);
    }

    function betsByUserLength(address user) external view returns (uint256) {
        return betsByUser[user].length;
    }

    /**
     * @dev Bets by date and user
     */
    function getBetsByDateAndUserFromTo(uint256 date, address user, uint256 from, uint256 to) public view returns (Bet[] memory) {
        uint256 cnt = to - from;
        Bet[] memory bets = new Bet[](cnt);
        for (uint256 i = 0; i < cnt; i++) {
            bets[i] = betById[betsByDateAndUser[date][user][from + i]];
        }
        return bets;
    }

    function getBetsByDateAndUser(uint256 date, address user) external view returns (Bet[] memory) {
        return getBetsByDateAndUserFromTo(date, user, 0, betsByDateAndUser[date][user].length);
    }

    function betsByDateAndUserLength(uint256 date, address user) external view returns (uint256) {
        return betsByDateAndUser[date][user].length;
    }

    /**
     * @dev Calculate approximate bet return
     */
    function calculateAproximateBetReturn(
        uint256 amount,
        uint32 choiceId,
        uint256 eventUID
    ) public view returns (uint256) {
        Event storage currentEvent = events[eventUID];
        require(currentEvent.uid != 0, "Event does not exist");
        require(
            currentEvent.startTime > block.timestamp,
            "Event already started"
        );

        uint256 totalChoiceAmount = currentEvent.choices[choiceId].totalBetsAmount +
            amount;
        uint256 totalPoolAmount = currentEvent.poolAmount + amount;
        uint256 multiplier = calculateMultiplier(totalChoiceAmount, totalPoolAmount);
        return amount * multiplier / MULTIPLIER_FACTOR;
    }
    
    function roundTimestampToDay(uint256 timestamp) private pure returns (uint256) {
        return timestamp - (timestamp % DAY);
    }


    // function checkResultHash(
    //     uint8 result,
    //     uint256 requestNumber,
    //     uint256 uid,
    //     uint256 resultHash
    // ) public pure returns (bool) {
    //     return resultHash == keccak256(abi.encodePacked(uid, requestNumber, result));
    // }

    function stringToUint256(string memory _uid) public pure returns (uint256) {
        return uint256(keccak256(abi.encodePacked(_uid)));
    }

    //function finalizeMatch(MatchResult.Proof calldata proof) external {
    //    // Check with state connector
    //    require(
    //        VERIFICATION.verifyMatchResult(proof),
    //        "MatchResult is not confirmed by the State Connector"
    //    );
    //
    //    uint256 uid = generateUID(
    //        Sports(proof.data.requestBody.sport),
    //        proof.data.requestBody.gender,
    //        proof.data.requestBody.date,
    //        proof.data.requestBody.teams
    //    );
    //
    //    SportEvent storage sportEvent = sportEvents[uid];
    //    require(sportEvent.uid != 0, "Event does not exist");
    //    require(sportEvent.winner == 0, "Result already drawn");
    //
    //    sportEvent.winner = proof.data.responseBody.result;
    //}

    function flipIsProduction() external onlyOwner {
        isProduction = !isProduction;
    }

    function setMaxBet(uint256 _maxBet) external onlyOwner {
        maxBet = _maxBet;
    }

    function withdraw(uint256 amount) external onlyOwner {
        require(!isProduction, "Cannot withdraw in production mode");
        
        TOKEN.safeTransfer(
            msg.sender, 
            amount
        );
    }

    /**
     * @dev Sets or revokes authorized address.
     * @param addr Address we are setting.
     * @param isAuthorized True is setting, false if we are revoking.
     */
    function setAuthorizedAddress(address addr, bool isAuthorized)
        external
        onlyOwner()
    {
        authorizedAddresses[addr] = isAuthorized;
    }

    function getFdcHub() external view returns (IFdcHub) {
        return ContractRegistry.getFdcHub();
    }

    function getFdcRequestFeeConfigurations()
        external
        view
        returns (IFdcRequestFeeConfigurations)
    {
        return ContractRegistry.getFdcRequestFeeConfigurations();
    }

}
