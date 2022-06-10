pragma solidity 0.8.4;

import "hardhat/console.sol";
import "./ExampleExternalContract.sol";

contract Staker {
    ExampleExternalContract public exampleExternalContract;

    mapping(address => uint256) public balances;
    mapping(address => uint256) public depositTimestamps;

    // TODO: Use a percentage as interest instead of fixed value
    uint256 public constant rewardRatePerBlock = 0.001 ether;
    uint256 public withdrawalDeadline = block.timestamp + 120 seconds;
    uint256 public claimDeadline = block.timestamp + 240 seconds;
    uint256 public currentBlock = 0;

    event Stake(address indexed sender, uint256 amount);
    event Received(address, uint256);
    event Execute(address indexed sender, uint256 amount);

    modifier withdrawalDeadlineReached(bool requireReached) {
        uint256 timeRemaining = withdrawalTimeLeft();
        if (requireReached) {
            require(timeRemaining == 0, "Withdrawal period is not reached yet");
        } else {
            require(timeRemaining > 0, "Withdrawal period has been reached");
        }
        _;
    }

    modifier claimDeadlineReached(bool requireReached) {
        uint256 timeRemaining = claimPeriodLeft();
        if (requireReached) {
            require(timeRemaining == 0, "Claim deadline is not reached yet");
        } else {
            require(timeRemaining > 0, "Claim deadline has been reached");
        }
        _;
    }

    modifier notCompleted() {
        bool completed = exampleExternalContract.completed();
        require(!completed, "Stake already completed!");
        _;
    }

    constructor(address exampleExternalContractAddress) public {
        exampleExternalContract = ExampleExternalContract(
            exampleExternalContractAddress
        );
    }

    // Stake function for a user to stake ETH in our contract
    function stake()
        public
        payable
        withdrawalDeadlineReached(false)
        claimDeadlineReached(false)
    {
        balances[msg.sender] = balances[msg.sender] + msg.value;
        depositTimestamps[msg.sender] = block.timestamp;
        emit Stake(msg.sender, msg.value);
    }

    /*
    Withdraw function for a user to remove their staked ETH inclusive
    of both the principle balance and any accrued interest
    */
    function withdraw()
        public
        withdrawalDeadlineReached(true)
        claimDeadlineReached(false)
        notCompleted
    {
        require(balances[msg.sender] > 0, "You have no balance to withdraw!");
        uint256 individualBalance = balances[msg.sender];
        // uint256 indBalanceRewards = individualBalance +
        //     ((block.timestamp - depositTimestamps[msg.sender]) *
        //         rewardRatePerBlock);

        uint256 age = block.timestamp - depositTimestamps[msg.sender];
        uint256 indBalanceRewards = individualBalance;
        uint256 x = 1;
        // duplicates the reward on each time/period
        while (x < age) {
            indBalanceRewards += rewardRatePerBlock * x;
            x++;
        }
        console.log("Age: ", age);
        console.log("rewardRatePerBlock: ", rewardRatePerBlock);
        console.log("individualBalance: ", individualBalance);
        console.log("indBalanceRewards: ", indBalanceRewards);

        balances[msg.sender] = 0;

        // Transfer all ETH via call! (not transfer) cc: https://solidity-by-example.org/sending-ether
        (bool sent, bytes memory data) = msg.sender.call{
            value: indBalanceRewards
        }("");
        require(sent, "RIP - withdrawal failed");
    }

    function withdrawalTimeLeft()
        public
        view
        returns (uint256 withdrawalTimeLeft)
    {
        if (block.timestamp >= withdrawalDeadline) {
            return (0);
        } else {
            return (withdrawalDeadline - block.timestamp);
        }
    }

    /*
    Allows any user to repatriate "unproductive" funds that are left in the staking contract
    past the defined withdrawal period
    */
    function execute() public claimDeadlineReached(true) notCompleted {
        uint256 contractBalance = address(this).balance;
        exampleExternalContract.complete{value: address(this).balance}();
    }

    function claimPeriodLeft() public view returns (uint256 claimPeriodLeft) {
        if (block.timestamp >= claimDeadline) {
            return (0);
        } else {
            return (claimDeadline - block.timestamp);
        }
    }

    /*
    Time to "kill-time" on our local testnet
    */
    function killTime() public {
        currentBlock = block.timestamp;
    }

    // TODO: implement a function that allows you to retrieve the ETH locked up in ExampleExternalContract and re-deposit it back into the Staker contract.
    function recoverStak() public {
        
    }

    /*
    \Function for our smart contract to receive ETH
    cc: https://docs.soliditylang.org/en/latest/contracts.html#receive-ether-function
    */
    receive() external payable {
        emit Received(msg.sender, msg.value);
    }
}
