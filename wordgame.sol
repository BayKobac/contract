// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

contract WordGuessingGame {
    address public owner;
    uint256 public prizePool;
    bool public gameEnded;
    bool public isAnswer;

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the contract owner");
        _;
    }

    constructor() {
        owner = msg.sender;
        gameEnded = false;
        isAnswer = false;
    }

    function restartGame() external {
        prizePool = 0;
        gameEnded = false;
        isAnswer = false;
    }

    function endGame() external {
        uint prize = prizePool;
        prizePool = 0;
        (bool success, ) = owner.call{value: prize}("");
        require(success, "Transfer failed");
        gameEnded = true;
    }

    function guessWord() external payable {
        require(msg.value == 0.001 ether, "Invalid value sent");
        prizePool += msg.value;
    }

    function changeStatus() external returns (bool) {
        isAnswer = true;
        return isAnswer;
    }

    function getGameState() external view returns (uint256, bool) {
        return (prizePool, gameEnded);
    }
}
