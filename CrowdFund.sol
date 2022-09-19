// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IERC20 {
    function transfer(address, uint) external returns (bool);

    function transferFrom(
        address,
        address,
        uint
    ) external returns (bool);
}
contract CrowdFund {
    event Launch(
        uint id,
        address indexed creator,
        uint goal,
        uint32 startTime,
        uint32 endTime
    );
    event Cancel(uint id);
    event Pledge(uint indexed id, address indexed caller, uint amount);
    event Unpledge(uint indexed id, address indexed caller, uint amount);
    event Claim(uint id);
    event Refund(uint id, address indexed caller, uint amount);

    struct campaign {
        address creator; //creator of the crowdfunder campaign
        uint goal; //the amount of tokens that the campaign wants to raise
        uint pledged; //total amount of tokens thhat are pledged to this campaign
        uint32 startTime;   //the time that the campaign starts
        uint32 endTime; //the time that the campaign ends
        bool claimed;
    }

    IERC20 public immutable token; //each contract handles 1 token for increased security
    uint public count; //keeps how many campaigns exist, increased every time new campaign is created
    mapping(uint => campaign) public campaigns; //keeps id of each campaign
    mapping(uint => mapping(address => uint)) public amountPledged;//amount of tokens each user pledged to campaign

    constructor (address _token) { // initialize state variables
        token = IERC20(_token); //only initialization necessary 
    }

    function launch (uint _goal, uint32 _startTime, uint32 _endTime) external {
        //check if inputs are valid
        require(_startTime >= block.timestamp, "start time is earlier than now"); //require start time to be later than now
        require(_endTime >= _startTime, "end time is earlier than start time"); //require end time to be later than start time
        require(_endTime <= block.timestamp + 30 days, "end time exceeded max duration"); //campaign ends in 30 days
        //after all requirements are met
        count++;
        campaigns[count] = campaign({
            creator: msg.sender,
            goal: _goal,
            pledged: 0,
            startTime: _startTime,
            endTime: _endTime,
            claimed: false
        });
        emit Launch(count, msg.sender, _goal, _startTime, _endTime);
    }
    function pledge (uint id, uint amount) external {
        campaign storage _campaign = campaigns[id];
        require(block.timestamp >= _campaign.startTime, "campaign has not started yet");//can only pledge after campaign hhas started
        require(block.timestamp <= _campaign.endTime, "campaign has ended"); //cannot pledge if campaign ended
        _campaign.pledged += amount; //add the amount to the total pledged amount of campaign
        amountPledged[id][msg.sender] += amount;  //keep track of senders and hhow much they sent
        token.transferFrom(msg.sender, address(this), amount); //transfer token from sender
        emit Pledge(id, msg.sender, amount);
    }
    function unpledge (uint id, uint amount) external {
        campaign storage _campaign = campaigns[id];
        require(block.timestamp <= _campaign.endTime, "campaign has ended"); //cannot unpledge if campaign ended
        _campaign.pledged -= amount;//decrease amount from total amount of pledge
        amountPledged[id][msg.sender] -= amount; 
        token.transfer(msg.sender, amount);
        emit Unpledge(id, msg.sender, amount);
    }
    function claim (uint id) external {
        campaign storage _campaign = campaigns[id];
        require(msg.sender == _campaign.creator, "only creator can claim"); //cannot claim if not creator
        require(block.timestamp > _campaign.endTime, "can only claim after campaign has ended"); //cannot claim if campaign has not ended
        require(_campaign.pledged >= _campaign.goal, "can only claim after goal is reached");//cannot claim if the total amount of pledges are not more than the goal
        require(!_campaign.claimed, "already claimed");
        _campaign.claimed = true;
        token.transfer(msg.sender, _campaign.pledged);
        emit Claim(id);
    }
    function refund (uint id) external {
        campaign storage _campaign = campaigns[id];
        require(block.timestamp > _campaign.endTime, "cannot refund while campaign has not ended");
        require(_campaign.pledged < _campaign.goal, "cannot refund if goal is reached");
        uint balance = amountPledged[id][msg.sender];
        amountPledged[id][msg.sender] = 0;
        token.transfer(msg.sender, balance);
        emit Refund(id, msg.sender, balance);
    }
    function cancel (uint id) external {
        campaign storage _campaign = campaigns[id];
        //only creator can cancel and only if it has not started yet
        require(msg.sender == _campaign.creator, "only creator can cancel");
        require(block.timestamp <= _campaign.startTime, "cannot be cancelled after campaign started");
        delete campaigns[id];
        emit Cancel(id);
    }
}
