import { expect } from "chai";
import { ethers } from "hardhat";
import { TestHelpers, TestEnvironment } from "../utils/TestHelpers";
import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";

describe("ReputationRegistry", function () {
  let env: TestEnvironment;
  let deployer: SignerWithAddress;
  let dao: SignerWithAddress;
  let platform1: SignerWithAddress;
  let platform2: SignerWithAddress;
  let trader1: SignerWithAddress;
  let trader2: SignerWithAddress;

  beforeEach(async function () {
    env = await TestHelpers.setupTestEnvironment();
    ({ deployer, dao, platform1, platform2, trader1, trader2 } = env);
  });

  describe("Deployment", function () {
    it("Should deploy with correct initial parameters", async function () {
      expect(await env.reputation.hasRole(await env.reputation.DEFAULT_ADMIN_ROLE(), deployer.address)).to.be.true;
      expect(await env.reputation.hasRole(await env.reputation.DAO_ROLE(), dao.address)).to.be.true;
      
      const usdcAddress = await env.usdc.getAddress();
      expect(await env.reputation.usdcToken()).to.equal(usdcAddress);
    });

    it("Should initialize with default parameters", async function () {
      const submissionFeeKey = TestHelpers.getParameterKey("PREPAID_SUBMISSION_FEE");
      const submissionFee = await env.reputation.getParameter(submissionFeeKey);
      expect(submissionFee).to.equal(TestHelpers.formatUSDC(1)); // $1.00
    });
  });

  describe("Contract Registration", function () {
    describe("registerPrepaidContract", function () {
      it("Should register prepaid contract successfully", async function () {
        const credits = TestHelpers.formatUSDC(200); // $200
        
        const tx = await TestHelpers.registerReputationContract(
          env.reputation,
          platform1,
          env.usdc,
          credits,
          "Test Platform 1"
        );

        await TestHelpers.expectEvent(tx, "ContractRegistered");

        const contractInfo = await env.reputation.getContractInfo(platform1.address);
        expect(contractInfo.tier).to.equal(TestHelpers.AuthTier.PREPAID);
        expect(contractInfo.active).to.be.true;
        expect(contractInfo.name).to.equal("Test Platform 1");

        const balance = await env.reputation.getCreditBalance(platform1.address);
        expect(balance).to.equal(credits);
      });

      it("Should reject registration with insufficient credits", async function () {
        const insufficientCredits = TestHelpers.formatUSDC(50); // Below $100 minimum
        
        await TestHelpers.approveUSDC(env.usdc, platform1, await env.reputation.getAddress(), insufficientCredits);
        
        await TestHelpers.expectRevert(
          env.reputation.connect(platform1).registerPrepaidContract(insufficientCredits, "Test Platform"),
          "insufficient initial credits"
        );
      });

      it("Should reject duplicate registration", async function () {
        const credits = TestHelpers.formatUSDC(200);
        
        await TestHelpers.registerReputationContract(
          env.reputation,
          platform1,
          env.usdc,
          credits,
          "Test Platform 1"
        );

        await TestHelpers.expectRevert(
          TestHelpers.registerReputationContract(
            env.reputation,
            platform1,
            env.usdc,
            credits,
            "Test Platform 1 Again"
          ),
          "contract already registered"
        );
      });

      it("Should reject empty name", async function () {
        const credits = TestHelpers.formatUSDC(200);
        await TestHelpers.approveUSDC(env.usdc, platform1, await env.reputation.getAddress(), credits);
        
        await TestHelpers.expectRevert(
          env.reputation.connect(platform1).registerPrepaidContract(credits, ""),
          "name cannot be empty"
        );
      });
    });

    describe("approveContract", function () {
      it("Should approve contract by DAO", async function () {
        const weight = 75;
        
        const tx = await env.reputation.connect(dao).approveContract(
          platform1.address,
          weight,
          "DAO Approved Platform"
        );

        await TestHelpers.expectEvent(tx, "ContractApproved");

        const contractInfo = await env.reputation.getContractInfo(platform1.address);
        expect(contractInfo.tier).to.equal(TestHelpers.AuthTier.DAO_APPROVED);
        expect(contractInfo.weight).to.equal(weight);
        expect(contractInfo.active).to.be.true;
      });

      it("Should reject approval by non-DAO", async function () {
        await TestHelpers.expectRevert(
          env.reputation.connect(platform1).approveContract(
            platform2.address,
            50,
            "Unauthorized Approval"
          ),
          "ReputationRegistry: caller is not DAO"
        );
      });

      it("Should reject weight above maximum", async function () {
        const maxWeight = await env.reputation.getParameter(TestHelpers.getParameterKey("MAX_CONTRACT_WEIGHT"));
        
        await TestHelpers.expectRevert(
          env.reputation.connect(dao).approveContract(
            platform1.address,
            Number(maxWeight) + 1,
            "Over Weight Platform"
          ),
          "weight exceeds maximum"
        );
      });
    });

    describe("revokeContract", function () {
      beforeEach(async function () {
        await env.reputation.connect(dao).approveContract(
          platform1.address,
          50,
          "Platform to Revoke"
        );
      });

      it("Should revoke contract by DAO", async function () {
        const tx = await env.reputation.connect(dao).revokeContract(
          platform1.address,
          "Terms violation"
        );

        await TestHelpers.expectEvent(tx, "ContractRevoked");

        const contractInfo = await env.reputation.getContractInfo(platform1.address);
        expect(contractInfo.active).to.be.false;
      });

      it("Should reject revocation by non-DAO", async function () {
        await TestHelpers.expectRevert(
          env.reputation.connect(platform1).revokeContract(
            platform1.address,
            "Self revocation"
          ),
          "ReputationRegistry: caller is not DAO"
        );
      });
    });

    describe("addCredits", function () {
      beforeEach(async function () {
        await TestHelpers.registerReputationContract(
          env.reputation,
          platform1,
          env.usdc,
          TestHelpers.formatUSDC(200),
          "Test Platform"
        );
      });

      it("Should add credits successfully", async function () {
        // Use a fresh platform to avoid credit balance limit issues from previous tests
        const [, , , , , , , , freshPlatform] = await ethers.getSigners();
        
        // Fund the fresh platform with USDC for registration and credits
        await env.usdc.transfer(freshPlatform.address, TestHelpers.formatUSDC(300));
        
        // Register the fresh platform first (using minimal initial credits to leave room for adding more)  
        await TestHelpers.registerReputationContract(
          env.reputation,
          freshPlatform,
          env.usdc,
          TestHelpers.formatUSDC(100), // Use minimum required amount  
          "Fresh Platform for Credits Test"
        );
        
        const initialBalance = await env.reputation.getCreditBalance(freshPlatform.address);
        const additionalCredits = TestHelpers.formatUSDC(50); // Add credits within limit
        
        await TestHelpers.approveUSDC(env.usdc, freshPlatform, await env.reputation.getAddress(), additionalCredits);
        
        const tx = await env.reputation.connect(freshPlatform).addCredits(additionalCredits);
        
        await TestHelpers.expectEvent(tx, "CreditsAdded");
        
        const finalBalance = await env.reputation.getCreditBalance(freshPlatform.address);
        expect(finalBalance - initialBalance).to.equal(additionalCredits);
      });

      it("Should reject credit addition by non-registered contract", async function () {
        const credits = TestHelpers.formatUSDC(100);
        await TestHelpers.approveUSDC(env.usdc, platform2, await env.reputation.getAddress(), credits);
        
        await TestHelpers.expectRevert(
          env.reputation.connect(platform2).addCredits(credits),
          "contract not registered or inactive"
        );
      });

      it("Should reject credit addition beyond max balance", async function () {
        const maxCredits = await env.reputation.getParameter(TestHelpers.getParameterKey("MAX_CREDIT_BALANCE"));
        const excessiveCredits = maxCredits + 1n;
        
        await TestHelpers.approveUSDC(env.usdc, platform1, await env.reputation.getAddress(), excessiveCredits);
        
        await TestHelpers.expectRevert(
          env.reputation.connect(platform1).addCredits(excessiveCredits),
          "would exceed max credit balance"
        );
      });
    });
  });

  describe("Data Submission", function () {
    beforeEach(async function () {
      // Register both prepaid and DAO-approved contracts
      await TestHelpers.registerReputationContract(
        env.reputation,
        platform1,
        env.usdc,
        TestHelpers.formatUSDC(200),
        "Prepaid Platform"
      );

      await env.reputation.connect(dao).approveContract(
        platform2.address,
        50,
        "DAO Approved Platform"
      );
    });

    describe("submitReputationEvent", function () {
      it("Should submit event from prepaid contract", async function () {
        const eventType = ethers.keccak256(ethers.toUtf8Bytes("trade_completed"));
        const eventId = ethers.keccak256(ethers.toUtf8Bytes("unique_event_1"));
        const value = 100;
        
        const initialBalance = await env.reputation.getCreditBalance(platform1.address);
        
        const tx = await env.reputation.connect(platform1).submitReputationEvent(
          trader1.address,
          eventType,
          value,
          eventId,
          "0x"
        );

        await TestHelpers.expectEvent(tx, "ReputationEventSubmitted");

        // Check credit deduction
        const finalBalance = await env.reputation.getCreditBalance(platform1.address);
        const submissionFee = TestHelpers.formatUSDC(1);
        expect(initialBalance - finalBalance).to.equal(submissionFee);

        // Check event count
        const eventCount = await env.reputation.getEventCount(platform1.address, trader1.address, eventType);
        expect(eventCount).to.equal(1);
      });

      it("Should submit event from DAO-approved contract without fee", async function () {
        const eventType = ethers.keccak256(ethers.toUtf8Bytes("trade_completed"));
        const eventId = ethers.keccak256(ethers.toUtf8Bytes("unique_event_2"));
        
        const tx = await env.reputation.connect(platform2).submitReputationEvent(
          trader1.address,
          eventType,
          100,
          eventId,
          "0x"
        );

        await TestHelpers.expectEvent(tx, "ReputationEventSubmitted");

        // No credit balance to check for DAO-approved
        const eventCount = await env.reputation.getEventCount(platform2.address, trader1.address, eventType);
        expect(eventCount).to.equal(1);
      });

      it("Should reject submission with insufficient credits", async function () {
        // Drain credits first by submitting many events
        const eventType = ethers.keccak256(ethers.toUtf8Bytes("trade_completed"));
        
        // Submit events until credits are exhausted
        for (let i = 0; i < 200; i++) {
          const eventId = ethers.keccak256(ethers.toUtf8Bytes(`event_${i}`));
          try {
            await env.reputation.connect(platform1).submitReputationEvent(
              trader1.address,
              eventType,
              100,
              eventId,
              "0x"
            );
          } catch (error) {
            // Expected when credits run out
            break;
          }
        }

        // Next submission should fail
        const finalEventId = ethers.keccak256(ethers.toUtf8Bytes("final_event"));
        await TestHelpers.expectRevert(
          env.reputation.connect(platform1).submitReputationEvent(
            trader1.address,
            eventType,
            100,
            finalEventId,
            "0x"
          ),
          "insufficient credits"
        );
      });

      it("Should reject duplicate event IDs", async function () {
        const eventType = ethers.keccak256(ethers.toUtf8Bytes("trade_completed"));
        const eventId = ethers.keccak256(ethers.toUtf8Bytes("duplicate_event"));
        
        await env.reputation.connect(platform1).submitReputationEvent(
          trader1.address,
          eventType,
          100,
          eventId,
          "0x"
        );

        await TestHelpers.expectRevert(
          env.reputation.connect(platform1).submitReputationEvent(
            trader2.address,
            eventType,
            100,
            eventId,
            "0x"
          ),
          "event already exists"
        );
      });

      it("Should reject submission from non-registered contract", async function () {
        const eventType = ethers.keccak256(ethers.toUtf8Bytes("trade_completed"));
        const eventId = ethers.keccak256(ethers.toUtf8Bytes("unauthorized_event"));
        
        await TestHelpers.expectRevert(
          env.reputation.connect(trader1).submitReputationEvent(
            trader2.address,
            eventType,
            100,
            eventId,
            "0x"
          ),
          "caller not registered or inactive"
        );
      });
    });

    describe("batchSubmitEvents", function () {
      it("Should batch submit events from DAO-approved contract", async function () {
        const eventType = ethers.keccak256(ethers.toUtf8Bytes("trade_completed"));
        const subjects = [trader1.address, trader2.address];
        const eventTypes = [eventType, eventType];
        const values = [100, 200];
        const eventIds = [
          ethers.keccak256(ethers.toUtf8Bytes("batch_event_1")),
          ethers.keccak256(ethers.toUtf8Bytes("batch_event_2"))
        ];

        const tx = await env.reputation.connect(platform2).batchSubmitEvents(
          subjects,
          eventTypes,
          values,
          eventIds
        );

        // Should emit events for each submission
        await TestHelpers.expectEvent(tx, "ReputationEventSubmitted");

        // Check that both events were recorded
        const count1 = await env.reputation.getEventCount(platform2.address, trader1.address, eventType);
        const count2 = await env.reputation.getEventCount(platform2.address, trader2.address, eventType);
        expect(count1).to.equal(1);
        expect(count2).to.equal(1);
      });

      it("Should reject batch submission from prepaid contract", async function () {
        const eventType = ethers.keccak256(ethers.toUtf8Bytes("trade_completed"));
        const subjects = [trader1.address];
        const eventTypes = [eventType];
        const values = [100];
        const eventIds = [ethers.keccak256(ethers.toUtf8Bytes("batch_event"))];

        await TestHelpers.expectRevert(
          env.reputation.connect(platform1).batchSubmitEvents(
            subjects,
            eventTypes,
            values,
            eventIds
          ),
          "only DAO-approved contracts can batch submit"
        );
      });

      it("Should reject batch with mismatched array lengths", async function () {
        const eventType = ethers.keccak256(ethers.toUtf8Bytes("trade_completed"));
        const subjects = [trader1.address, trader2.address];
        const eventTypes = [eventType]; // Different length
        const values = [100, 200];
        const eventIds = [
          ethers.keccak256(ethers.toUtf8Bytes("batch_event_1")),
          ethers.keccak256(ethers.toUtf8Bytes("batch_event_2"))
        ];

        await TestHelpers.expectRevert(
          env.reputation.connect(platform2).batchSubmitEvents(
            subjects,
            eventTypes,
            values,
            eventIds
          ),
          "array length mismatch"
        );
      });

      it("Should reject batch exceeding max size", async function () {
        const maxBatchSize = await env.reputation.getParameter(TestHelpers.getParameterKey("MAX_BATCH_SIZE"));
        const oversizedBatch = Number(maxBatchSize) + 1;
        
        const subjects = new Array(oversizedBatch).fill(trader1.address);
        const eventTypes = new Array(oversizedBatch).fill(ethers.keccak256(ethers.toUtf8Bytes("trade_completed")));
        const values = new Array(oversizedBatch).fill(100);
        const eventIds = Array.from({length: oversizedBatch}, (_, i) => 
          ethers.keccak256(ethers.toUtf8Bytes(`batch_event_${i}`))
        );

        await TestHelpers.expectRevert(
          env.reputation.connect(platform2).batchSubmitEvents(
            subjects,
            eventTypes,
            values,
            eventIds
          ),
          "batch size exceeds maximum"
        );
      });
    });

    describe("updateUserStatus", function () {
      it("Should update user status from prepaid contract", async function () {
        const statusValue = 5; // Premium tier
        const expiryDate = Math.floor(Date.now() / 1000) + 86400; // 1 day from now

        const initialBalance = await env.reputation.getCreditBalance(platform1.address);
        
        const tx = await env.reputation.connect(platform1).updateUserStatus(
          trader1.address,
          statusValue,
          expiryDate
        );

        await TestHelpers.expectEvent(tx, "UserStatusUpdated");

        // Check credit deduction
        const finalBalance = await env.reputation.getCreditBalance(platform1.address);
        const submissionFee = TestHelpers.formatUSDC(1);
        expect(initialBalance - finalBalance).to.equal(submissionFee);

        // Check status
        const userStatus = await env.reputation.getUserStatus(platform1.address, trader1.address);
        expect(userStatus.statusValue).to.equal(statusValue);
        expect(userStatus.expiryDate).to.equal(expiryDate);
        expect(userStatus.active).to.be.true;
      });

      it("Should update user status from DAO-approved contract without fee", async function () {
        const statusValue = 10;
        const expiryDate = 0; // No expiry

        const tx = await env.reputation.connect(platform2).updateUserStatus(
          trader1.address,
          statusValue,
          expiryDate
        );

        await TestHelpers.expectEvent(tx, "UserStatusUpdated");

        const userStatus = await env.reputation.getUserStatus(platform2.address, trader1.address);
        expect(userStatus.statusValue).to.equal(statusValue);
        expect(userStatus.expiryDate).to.equal(expiryDate);
      });
    });

    describe("batchUpdateUserStatuses", function () {
      it("Should batch update user statuses from DAO-approved contract", async function () {
        const users = [trader1.address, trader2.address];
        const statusValues = [5, 10];
        const expiryDates = [0, Math.floor(Date.now() / 1000) + 86400];

        const tx = await env.reputation.connect(platform2).batchUpdateUserStatuses(
          users,
          statusValues,
          expiryDates
        );

        await TestHelpers.expectEvent(tx, "UserStatusUpdated");

        // Check both statuses
        const status1 = await env.reputation.getUserStatus(platform2.address, trader1.address);
        const status2 = await env.reputation.getUserStatus(platform2.address, trader2.address);
        
        expect(status1.statusValue).to.equal(statusValues[0]);
        expect(status2.statusValue).to.equal(statusValues[1]);
      });

      it("Should reject batch update from prepaid contract", async function () {
        const users = [trader1.address];
        const statusValues = [5];
        const expiryDates = [0];

        await TestHelpers.expectRevert(
          env.reputation.connect(platform1).batchUpdateUserStatuses(
            users,
            statusValues,
            expiryDates
          ),
          "only DAO-approved contracts can batch update"
        );
      });
    });
  });

  describe("Data Retrieval", function () {
    beforeEach(async function () {
      // Set up test data
      await env.reputation.connect(dao).approveContract(
        platform1.address,
        50,
        "Test Platform"
      );

      const eventType = ethers.keccak256(ethers.toUtf8Bytes("trade_completed"));
      
      // Submit multiple events
      for (let i = 0; i < 5; i++) {
        const eventId = ethers.keccak256(ethers.toUtf8Bytes(`test_event_${i}`));
        await env.reputation.connect(platform1).submitReputationEvent(
          trader1.address,
          eventType,
          100 + i,
          eventId,
          "0x"
        );
      }
    });

    describe("getReputationEvents", function () {
      it("Should return all events for user", async function () {
        const eventType = ethers.keccak256(ethers.toUtf8Bytes("trade_completed"));
        const events = await env.reputation.getReputationEvents(
          platform1.address,
          trader1.address,
          eventType
        );

        expect(events.length).to.equal(5);
        expect(events[0].subject).to.equal(trader1.address);
        expect(events[0].value).to.equal(100);
      });
    });

    describe("getEventCount", function () {
      it("Should return correct event count", async function () {
        const eventType = ethers.keccak256(ethers.toUtf8Bytes("trade_completed"));
        const count = await env.reputation.getEventCount(
          platform1.address,
          trader1.address,
          eventType
        );

        expect(count).to.equal(5);
      });
    });

    describe("getRecentEvents", function () {
      it("Should return recent events with limit", async function () {
        const eventType = ethers.keccak256(ethers.toUtf8Bytes("trade_completed"));
        const events = await env.reputation.getRecentEvents(
          platform1.address,
          trader1.address,
          eventType,
          3
        );

        expect(events.length).to.equal(3);
        // Should return the most recent events (last 3)
        expect(events[0].value).to.equal(102); // 100 + 2
      });

      it("Should return empty array for zero limit", async function () {
        const eventType = ethers.keccak256(ethers.toUtf8Bytes("trade_completed"));
        const events = await env.reputation.getRecentEvents(
          platform1.address,
          trader1.address,
          eventType,
          0
        );

        expect(events.length).to.equal(0);
      });
    });

    describe("getEventsPaginated", function () {
      it("Should return paginated events", async function () {
        const eventType = ethers.keccak256(ethers.toUtf8Bytes("trade_completed"));
        const result = await env.reputation.getEventsPaginated(
          platform1.address,
          trader1.address,
          eventType,
          1, // offset
          2  // limit
        );

        expect(result.events.length).to.equal(2);
        expect(result.total).to.equal(5);
        expect(result.hasMore).to.be.true;
        
        // Should return events at offset 1 and 2
        expect(result.events[0].value).to.equal(101); // 100 + 1
        expect(result.events[1].value).to.equal(102); // 100 + 2
      });

      it("Should handle pagination edge cases", async function () {
        const eventType = ethers.keccak256(ethers.toUtf8Bytes("trade_completed"));
        
        // Test offset beyond total
        const result1 = await env.reputation.getEventsPaginated(
          platform1.address,
          trader1.address,
          eventType,
          10, // offset beyond total
          2
        );
        
        expect(result1.events.length).to.equal(0);
        expect(result1.total).to.equal(5);
        expect(result1.hasMore).to.be.false;

        // Test last page
        const result2 = await env.reputation.getEventsPaginated(
          platform1.address,
          trader1.address,
          eventType,
          4, // last item
          2
        );
        
        expect(result2.events.length).to.equal(1);
        expect(result2.hasMore).to.be.false;
      });
    });

    describe("getUserStatus", function () {
      it("Should return user status", async function () {
        await env.reputation.connect(platform1).updateUserStatus(
          trader1.address,
          42,
          0
        );

        const status = await env.reputation.getUserStatus(platform1.address, trader1.address);
        expect(status.statusValue).to.equal(42);
        expect(status.active).to.be.true;
      });
    });

    describe("isStatusActive", function () {
      it("Should return true for active status", async function () {
        await env.reputation.connect(platform1).updateUserStatus(
          trader1.address,
          5,
          0 // No expiry
        );

        const isActive = await env.reputation.isStatusActive(platform1.address, trader1.address);
        expect(isActive).to.be.true;
      });

      it("Should return false for expired status", async function () {
        const pastExpiry = Math.floor(Date.now() / 1000) - 86400; // 1 day ago
        
        await env.reputation.connect(platform1).updateUserStatus(
          trader1.address,
          5,
          pastExpiry
        );

        const isActive = await env.reputation.isStatusActive(platform1.address, trader1.address);
        expect(isActive).to.be.false;
      });
    });

    describe("getBatchUserStatuses", function () {
      it("Should return multiple user statuses", async function () {
        await env.reputation.connect(platform1).updateUserStatus(
          trader1.address,
          5,
          0
        );
        await env.reputation.connect(platform1).updateUserStatus(
          trader2.address,
          10,
          0
        );

        const statuses = await env.reputation.getBatchUserStatuses(
          platform1.address,
          [trader1.address, trader2.address]
        );

        expect(statuses.length).to.equal(2);
        expect(statuses[0].statusValue).to.equal(5);
        expect(statuses[1].statusValue).to.equal(10);
      });
    });
  });

  describe("Revenue System", function () {
    beforeEach(async function () {
      await TestHelpers.registerReputationContract(
        env.reputation,
        platform1,
        env.usdc,
        TestHelpers.formatUSDC(200),
        "Revenue Test Platform"
      );
    });

    it("Should track fees collected", async function () {
      const initialTotal = await env.reputation.getTotalFeesCollected();
      
      const eventType = ethers.keccak256(ethers.toUtf8Bytes("trade_completed"));
      const eventId = ethers.keccak256(ethers.toUtf8Bytes("revenue_event"));
      
      await env.reputation.connect(platform1).submitReputationEvent(
        trader1.address,
        eventType,
        100,
        eventId,
        "0x"
      );

      const finalTotal = await env.reputation.getTotalFeesCollected();
      const submissionFee = TestHelpers.formatUSDC(1);
      
      expect(finalTotal - initialTotal).to.equal(submissionFee);
    });

    it("Should allow DAO to withdraw fees", async function () {
      // Generate some fees first
      const eventType = ethers.keccak256(ethers.toUtf8Bytes("trade_completed"));
      for (let i = 0; i < 5; i++) {
        const eventId = ethers.keccak256(ethers.toUtf8Bytes(`fee_event_${i}`));
        await env.reputation.connect(platform1).submitReputationEvent(
          trader1.address,
          eventType,
          100,
          eventId,
          "0x"
        );
      }

      const reputationAddress = await env.reputation.getAddress();
      const contractBalance = await env.usdc.balanceOf(reputationAddress);
      const initialDAOBalance = await env.usdc.balanceOf(dao.address);

      await env.reputation.connect(dao).withdrawFees(contractBalance);

      const finalDAOBalance = await env.usdc.balanceOf(dao.address);
      expect(finalDAOBalance - initialDAOBalance).to.equal(contractBalance);
    });
  });

  describe("Parameter Management", function () {
    it("Should update parameters by DAO", async function () {
      const submissionFeeKey = TestHelpers.getParameterKey("PREPAID_SUBMISSION_FEE");
      const newFee = TestHelpers.formatUSDC(2); // $2.00
      
      const tx = await env.reputation.connect(dao).updateParameter(submissionFeeKey, newFee);
      
      await TestHelpers.expectEvent(tx, "ParameterUpdated");
      
      const updatedFee = await env.reputation.getParameter(submissionFeeKey);
      expect(updatedFee).to.equal(newFee);
    });

    it("Should reject parameter updates from non-DAO", async function () {
      const submissionFeeKey = TestHelpers.getParameterKey("PREPAID_SUBMISSION_FEE");
      
      await TestHelpers.expectRevert(
        env.reputation.connect(platform1).updateParameter(submissionFeeKey, TestHelpers.formatUSDC(2)),
        "caller is not DAO"
      );
    });
  });

  describe("Security Features", function () {
    describe("Pause Mechanism", function () {
      it("Should pause contract", async function () {
        await env.reputation.connect(env.pauser).pause();
        
        await TestHelpers.expectRevert(
          TestHelpers.registerReputationContract(
            env.reputation,
            platform1,
            env.usdc,
            TestHelpers.formatUSDC(200),
            "Paused Platform"
          ),
          "Pausable: paused"
        );
      });
    });

    describe("Access Control", function () {
      it("Should enforce contract registration", async function () {
        const eventType = ethers.keccak256(ethers.toUtf8Bytes("trade_completed"));
        const eventId = ethers.keccak256(ethers.toUtf8Bytes("unauthorized_event"));
        
        await TestHelpers.expectRevert(
          env.reputation.connect(platform1).submitReputationEvent(
            trader1.address,
            eventType,
            100,
            eventId,
            "0x"
          ),
          "caller not registered or inactive"
        );
      });
    });
  });

  describe("Edge Cases", function () {
    it("Should handle zero-length arrays gracefully", async function () {
      await env.reputation.connect(dao).approveContract(
        platform1.address,
        50,
        "Test Platform"
      );

      await TestHelpers.expectRevert(
        env.reputation.connect(platform1).batchSubmitEvents([], [], [], []),
        "empty arrays"
      );
    });

    it("Should handle max values correctly", async function () {
      // Test with maximum values where applicable
      const maxValue = 2**32 - 1; // Max uint32
      
      await env.reputation.connect(dao).approveContract(
        platform1.address,
        50,
        "Max Value Platform"
      );

      const eventType = ethers.keccak256(ethers.toUtf8Bytes("max_test"));
      const eventId = ethers.keccak256(ethers.toUtf8Bytes("max_event"));
      
      const tx = await env.reputation.connect(platform1).submitReputationEvent(
        trader1.address,
        eventType,
        maxValue,
        eventId,
        "0x"
      );

      await TestHelpers.expectEvent(tx, "ReputationEventSubmitted");
    });
  });
});