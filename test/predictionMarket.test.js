const { expect } = require("chai");
const { BN, expectEvent, expectRevert } = require("@openzeppelin/test-helpers");
const PredictionMarket = artifacts.require("PredictionMarket");

contract("PredictionMarket", (accounts) => {
  let predictionMarket;
  const owner = accounts[0];
  const user1 = accounts[1];
  const user2 = accounts[2];

  beforeEach(async () => {
    predictionMarket = await PredictionMarket.new({ from: owner });
  });

  // Test 1: Contract deployment
  it("should deploy and set the owner", async () => {
    const contractOwner = await predictionMarket.owner();
    expect(contractOwner).to.equal(owner);
  });

  // Test 2: Create a prediction
  it("should create a new prediction", async () => {
    const question = "Will ETH hit $3000 by 2024?";
    const deadline = Math.floor(Date.now() / 1000) + 3600; // 1 hour from now

    const tx = await predictionMarket.createPrediction(question, deadline, { from: owner });
    
    // Check event emission
    expectEvent(tx, "PredictionCreated", {
      predictionId: new BN(0),
      question: question,
      deadline: new BN(deadline),
    });

    // Check stored prediction
    const prediction = await predictionMarket.predictions(0);
    expect(prediction.question).to.equal(question);
    expect(prediction.deadline).to.be.bignumber.equal(new BN(deadline));
  });

  // Test 3: Place a bet
  it("should allow users to place bets", async () => {
    const question = "Test Question";
    const deadline = Math.floor(Date.now() / 1000) + 3600;
    await predictionMarket.createPrediction(question, deadline, { from: owner });

    const betAmount = web3.utils.toWei("1", "ether");
    const choice = 1; // Yes

    await predictionMarket.placeBet(0, choice, {
      from: user1,
      value: betAmount,
    });

    const betInfo = await predictionMarket.predictions(0);
    expect(betInfo.totalYesBets).to.be.bignumber.equal(new BN(betAmount));
  });

  // Test 4: Resolve a prediction
  it("should resolve a prediction and emit an event", async () => {
    const question = "Test Question";
    const deadline = Math.floor(Date.now() / 1000) - 3600; // Expired deadline
    await predictionMarket.createPrediction(question, deadline, { from: owner });

    const outcome = 1; // Yes
    const tx = await predictionMarket.resolvePrediction(0, outcome, { from: owner });

    // Check event and resolution status
    expectEvent(tx, "PredictionResolved", {
      predictionId: new BN(0),
      outcome: new BN(outcome),
    });
    const prediction = await predictionMarket.predictions(0);
    expect(prediction.resolved).to.be.true;
  });

  // Test 5: Claim rewards
  it("should allow users to claim rewards", async () => {
    // Create and resolve a prediction
    const question = "Test Question";
    const deadline = Math.floor(Date.now() / 1000) - 3600;
    await predictionMarket.createPrediction(question, deadline, { from: owner });
    await predictionMarket.resolvePrediction(0, 1, { from: owner });

    // Place a winning bet
    const betAmount = web3.utils.toWei("1", "ether");
    await predictionMarket.placeBet(0, 1, {
      from: user1,
      value: betAmount,
    });

    // Claim reward
    const tx = await predictionMarket.claimReward(0, { from: user1 });
    expectEvent(tx, "RewardClaimed", {
      predictionId: new BN(0),
      claimant: user1,
    });
  });
});