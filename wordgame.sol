// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

contract WordGuessingGame {
    address public owner;
    string private answer;
    uint256 public prizePool;
    bool public gameEnded;

    event WordGuessed(address indexed player, string guess, bool isCorrect);
    event GameStarted(string newAnswer);

    constructor() {
        owner = msg.sender;
        answer = "apple";
        gameEnded = false;
    }

    function setAnswer(string memory newAnswer) external {
        require(msg.sender == owner, "Only owner can set the answer");
        answer = newAnswer;
        gameEnded = false;
        emit GameStarted(newAnswer); // 새로운 게임 시작 이벤트
    }

    function deposit() external payable {
        require(!gameEnded, "Game has already ended");
        prizePool += msg.value;
    }

    function guessWord(string calldata guessedWord) external {
        require(!gameEnded, "Game has already ended");

        bool isCorrect = keccak256(abi.encodePacked(guessedWord)) 
            == keccak256(abi.encodePacked(answer));

        emit WordGuessed(msg.sender, guessedWord, isCorrect);

        if (isCorrect) {
            payable(msg.sender).transfer(prizePool);
            prizePool = 0;
            gameEnded = true;
        }
    }
}
