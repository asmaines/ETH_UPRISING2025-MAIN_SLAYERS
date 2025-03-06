// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

contract MilestoneFunding {
    address public business;
    address public financialAdvisor;
    uint public totalFundingGoal = 100 ether;
    uint public fundingDeadline;
    uint public projectDeadline;
    uint public totalFundsRaised;
    uint public milestoneIndex;
    
    struct Milestone {
        uint percentage;
        bool approved;
        uint pleasUsed;
    }
    
    Milestone[] public milestones;
    mapping(address => uint) public investorContributions;
    address[] public investors;
    
    event Funded(address indexed investor, uint amount);
    event MilestoneApproved(uint indexed milestoneIndex);
    event FundsReleased(uint indexed milestoneIndex, uint amount);
    event PleaSubmitted(uint indexed milestoneIndex);
    event PleaRejected(uint indexed milestoneIndex, uint pleasUsed);
    event RefundIssued(address indexed investor, uint amount);
    
    modifier onlyBusiness() {
        require(msg.sender == business, "Only business can call this");
        _;
    }
    
    constructor(address _business, address _financialAdvisor, uint _fundingPeriod, uint _projectPeriod) {
        business = _business;
        financialAdvisor = _financialAdvisor;
        fundingDeadline = block.timestamp + _fundingPeriod;
        projectDeadline = fundingDeadline + _projectPeriod;
        
        milestones.push(Milestone(30, false, 0));
        milestones.push(Milestone(20, false, 0));
        milestones.push(Milestone(30, false, 0));
        milestones.push(Milestone(20, false, 0));
    }
    
    function contribute() external payable {
        require(block.timestamp < fundingDeadline, "Funding period ended");
        require(totalFundsRaised + msg.value <= totalFundingGoal, "Exceeds goal");
        
        if (investorContributions[msg.sender] == 0) {
            investors.push(msg.sender);
        }
        investorContributions[msg.sender] += msg.value;
        totalFundsRaised += msg.value;
        
        emit Funded(msg.sender, msg.value);
    }
    
    function approveMilestone() external {
        require(msg.sender == financialAdvisor, "Only advisor can approve");
        require(milestoneIndex < milestones.length, "All milestones completed");
        require(!milestones[milestoneIndex].approved, "Already approved");
        
        milestones[milestoneIndex].approved = true;
        uint amount = (totalFundsRaised * milestones[milestoneIndex].percentage) / 100;
        payable(business).transfer(amount);
        
        emit FundsReleased(milestoneIndex, amount);
        milestoneIndex++;
    }
    
    function requestPlea() external onlyBusiness {
        require(milestoneIndex < milestones.length, "No more milestones");
        require(milestones[milestoneIndex].pleasUsed < 3, "Max pleas used");
        
        milestones[milestoneIndex].pleasUsed++;
        emit PleaSubmitted(milestoneIndex);
    }
    
    function rejectPlea() external {
        require(msg.sender == financialAdvisor, "Only advisor can reject");
        require(milestones[milestoneIndex].pleasUsed > 0, "No plea to reject");
        
        emit PleaRejected(milestoneIndex, milestones[milestoneIndex].pleasUsed);
        
        if (milestones[milestoneIndex].pleasUsed >= 3) {
            refundInvestors();
        }
    }
    
    function refundInvestors() internal {
        for (uint i = 0; i < investors.length; i++) {
            address investor = investors[i];
            uint amount = investorContributions[investor];
            if (amount > 0) {
                investorContributions[investor] = 0;
                payable(investor).transfer(amount);
                emit RefundIssued(investor, amount);
            }
        }
    }
    
    function claimRefund() external {
        require(block.timestamp > fundingDeadline, "Funding still open");
        require(totalFundsRaised < totalFundingGoal, "Goal met, no refund");
        
        uint amount = investorContributions[msg.sender];
        require(amount > 0, "No contribution found");
        investorContributions[msg.sender] = 0;
        payable(msg.sender).transfer(amount);
        emit RefundIssued(msg.sender, amount);
    }
}
