// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

contract WordGuessingGame {
    address public owner;
    bytes32 private answerHash; // 정답의 해시 값
    uint256 public prizePool; // 상금 풀
    bool public gameEnded;

    event WordGuessed(address indexed player, string guess, bool isCorrect);
    event GameRestarted(address indexed owner, bytes32 newAnswerHash);

    constructor() {
        owner = msg.sender;
        _restartGame("block"); // 초기 정답 
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can perform this action");
        _;
    }

    function _restartGame(string memory newAnswer) internal {
        require(bytes(newAnswer).length > 0, "Answer cannot be empty");
        answerHash = keccak256(abi.encodePacked(newAnswer));
        prizePool = 0; // 상금 풀 초기화
        gameEnded = false;
        emit GameRestarted(msg.sender, answerHash);
    }

    function setAnswer(string memory newAnswer) external onlyOwner {
        _restartGame(newAnswer);
    } //owner만 호출가능 game restart 하라고

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

            require(msg.sender == owner, "Backend must set a new answer!");
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
