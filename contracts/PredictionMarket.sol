// SPDX-License-Identifier: MIT
pragma solidity  ^0.8.28;
import "../node_modules/@openzeppelin/contracts/security/ReentrancyGuard.sol";
contract PredictionMarket is ReentrancyGuard {
    struct BetInfo {
        uint256 amount;
        uint8 choice; // 1 = Yes, 2 = No
        bool claimed;
    }

    struct Prediction {
        string question;
        uint256 deadline;
        address[] participants;
        mapping(address => BetInfo) bets;
        mapping(address => bool) hasParticipated;
        uint256 totalYesBets;
        uint256 totalNoBets;
        uint256 outcome; // 0 = unresolved, 1 = Yes, 2 = No
        bool resolved;
    }

    uint256 public predictionCount;
    mapping(uint256 => Prediction) public predictions;
    address public owner;

    event PredictionCreated(uint256 indexed predictionId, string question, uint256 deadline);
    event BetPlaced(uint256 indexed predictionId, address participant, uint256 amount, uint8 choice);
    event PredictionResolved(uint256 indexed predictionId, uint256 outcome);
    event RewardClaimed(uint256 indexed predictionId, address claimant, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this.");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function createPrediction(string memory _question, uint256 _deadline) external {
        require(_deadline > block.timestamp, "Deadline must be in the future.");
        uint256 predictionId = predictionCount++;
        Prediction storage p = predictions[predictionId];
        p.question = _question;
        p.deadline = _deadline;
        emit PredictionCreated(predictionId, _question, _deadline);
    }

    function placeBet(uint256 _predictionId, uint8 _choice) external payable nonReentrant {
        require(_choice == 1 || _choice == 2, "Invalid choice (1=Yes, 2=No).");
        Prediction storage p = predictions[_predictionId];
        require(block.timestamp < p.deadline, "Betting closed.");
        require(msg.value > 0, "Bet amount must be > 0.");

        BetInfo storage bet = p.bets[msg.sender];
        bet.amount += msg.value;
        bet.choice = _choice;

        if (!p.hasParticipated[msg.sender]) {
            p.participants.push(msg.sender);
            p.hasParticipated[msg.sender] = true;
        }

        if (_choice == 1) p.totalYesBets += msg.value;
        else p.totalNoBets += msg.value;

        emit BetPlaced(_predictionId, msg.sender, msg.value, _choice);
    }

    function resolvePrediction(uint256 _predictionId, uint256 _outcome) external onlyOwner {
        require(_outcome == 1 || _outcome == 2, "Invalid outcome.");
        Prediction storage p = predictions[_predictionId];
        require(!p.resolved, "Already resolved.");
        require(block.timestamp >= p.deadline, "Deadline not met.");
        p.outcome = _outcome;
        p.resolved = true;
        emit PredictionResolved(_predictionId, _outcome);
    }

    function claimReward(uint256 _predictionId) external nonReentrant {
        Prediction storage p = predictions[_predictionId];
        require(p.resolved, "Not resolved.");
        BetInfo storage bet = p.bets[msg.sender];
        require(bet.amount > 0 && !bet.claimed, "Invalid claim.");
        require(bet.choice == p.outcome, "You lost.");

        uint256 totalPool = (p.outcome == 1) ? p.totalYesBets : p.totalNoBets;
        uint256 reward = (bet.amount * (p.totalYesBets + p.totalNoBets)) / totalPool;

        bet.claimed = true;
        payable(msg.sender).transfer(reward);
        emit RewardClaimed(_predictionId, msg.sender, reward);
    }

    receive() external payable {}
}