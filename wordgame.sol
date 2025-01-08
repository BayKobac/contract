// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

contract WordGuessingGame {
    address public owner;
    bytes32 private answerHash;       // 정답의 해시 값
    uint256 public prizePool;         // 상금 풀
    bool public gameEnded;

    event WordGuessed(address indexed player, string guess, bool isCorrect);
    event GameRestarted(address indexed owner, bytes32 newAnswerHash);

    constructor() {
        owner = msg.sender;
        answerHash = keccak256(abi.encodePacked("apple")); // 초기 정답
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can perform this action");
        _;
    }

    function setAnswer(string memory newAnswer) external onlyOwner {
        require(bytes(newAnswer).length > 0, "Answer cannot be empty");
        answerHash = keccak256(abi.encodePacked(newAnswer));
        gameEnded = false; // 새 게임 시작
        emit GameRestarted(msg.sender, answerHash);
    }

    function guessWord(string calldata guessedWord) external payable {
        require(!gameEnded, "Game has already ended");
        require(msg.value == 0.001 ether, "You must deposit 0.001 ETH to guess");
        require(bytes(guessedWord).length > 0, "Guess cannot be empty");

        prizePool += msg.value;

        bool isCorrect = keccak256(abi.encodePacked(guessedWord)) == answerHash;

        emit WordGuessed(msg.sender, guessedWord, isCorrect);

        if (isCorrect) {
            uint256 prize = prizePool;
            prizePool = 0;
            gameEnded = true;

            (bool success, ) = msg.sender.call{value: prize}("");
            require(success, "Transfer failed");
        }
    }

    function getGameState() external view returns (uint256, bool) {
        return (prizePool, gameEnded);
    }

    function withdrawAll() external onlyOwner {
        require(gameEnded, "Game is still active");
        uint256 balance = address(this).balance;
        require(balance > 0, "No balance to withdraw");

        (bool success, ) = owner.call{value: balance}("");
        require(success, "Withdrawal failed");
    }
}
