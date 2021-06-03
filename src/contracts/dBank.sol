// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;

import "./Token.sol";

contract dBank {
    Token private token;

    mapping(address => uint256) public etherBalanceOf;
    mapping(address => uint256) public depositStart;
    mapping(address => bool) public isDeposited;
    mapping(address => uint256) public collateralEther;
    mapping(address => bool) public isBorrowed;

    event Deposit(address indexed user, uint256 etherAmount, uint256 timeStart);
    event Withdraw(
        address indexed user,
        uint256 etherAmount,
        uint256 depositTime,
        uint256 interest
    );
    event Borrow(
        address indexed user,
        uint256 collateralEtherAmount,
        uint256 borrowedTokenAmount
    );
    event PayOff(address indexed user, uint256 fee);

    constructor(Token _token) public {
        token = _token;
    }

    function deposit() public payable {
        require(
            isDeposited[msg.sender] == false,
            "Error, deposit already active"
        );
        require(msg.value >= 1e16, "Error, deposit must be >= 0.01 ETH");

        etherBalanceOf[msg.sender] += msg.value;
        depositStart[msg.sender] += block.timestamp;
        isDeposited[msg.sender] = true;

        emit Deposit(msg.sender, msg.value, block.timestamp);
    }

    function withdraw() public {
        require(isDeposited[msg.sender] == true, "Error, no previous deposit");
        uint256 userBalance = etherBalanceOf[msg.sender];

        uint256 depositTime = block.timestamp - depositStart[msg.sender];

        uint256 interestPerSecond =
            31668017 * (etherBalanceOf[msg.sender] / 1e16);
        uint256 interest = interestPerSecond * depositTime;

        //send eth to user
        msg.sender.transfer(userBalance);
        token.mint(msg.sender, interest);

        depositStart[msg.sender] = 0;
        etherBalanceOf[msg.sender] = 0;
        isDeposited[msg.sender] = false;

        emit Withdraw(msg.sender, userBalance, depositTime, interest);
    }

    function borrow() public payable {
        require(msg.value >= 1e16, "Error, collateral must be >= 0.01 ETH");
        require(isBorrowed[msg.sender] == false, "Error, loan already taken");

        collateralEther[msg.sender] = collateralEther[msg.sender] + msg.value;

        uint256 tokensToMint = collateralEther[msg.sender] / 2;

        token.mint(msg.sender, tokensToMint);

        isBorrowed[msg.sender] = true;

        emit Borrow(msg.sender, collateralEther[msg.sender], tokensToMint);
    }

    function payOff() public {
        require(isBorrowed[msg.sender] == true, "Error, loan not active");
        require(
            token.transferFrom(
                msg.sender,
                address(this),
                collateralEther[msg.sender] / 2
            ),
            "Error, can't receive tokens"
        ); //must approve dBank 1st

        uint256 fee = collateralEther[msg.sender] / 10;

        msg.sender.transfer(collateralEther[msg.sender] - fee);

        collateralEther[msg.sender] = 0;
        isBorrowed[msg.sender] = false;

        emit PayOff(msg.sender, fee);
    }
}
