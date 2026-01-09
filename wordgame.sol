// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

contract WordGuessingGameV2 {
    // ---- Errors (cheaper than require strings) ----
    error NotOwner();
    error GameNotActive();
    error GameAlreadyActive();
    error GameAlreadyEnded();
    error InvalidEntryFee();
    error AnswerNotSet();
    error NoPendingWithdrawal();
    error TransferFailed();

    // ---- Basic reentrancy guard (self-contained) ----
    uint256 private _locked = 1;
    modifier nonReentrant() {
        require(_locked == 1, "REENTRANCY");
        _locked = 2;
        _;
        _locked = 1;
    }

    // ---- Ownership ----
    address public immutable owner;
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    // ---- Game state ----
    enum GameState { NotStarted, Active, Ended }
    GameState public gameState;

    uint256 public constant ENTRY_FEE = 0.001 ether;

    // 정답 해시(평문 저장 X)
    bytes32 public answerHash;

    // 우승자 / 상금 지급 기록
    address public winner;

    // 전송 실패 대비(보류 출금)
    mapping(address => uint256) public pendingWithdrawals;

    // 참여 기록(옵션)
    mapping(address => uint256) public totalPaid;

    // ---- Events ----
    event GameStarted(bytes32 indexed answerHash);
    event GameRestarted(bytes32 indexed answerHash);
    event GameCancelled(uint256 ownerPayout);
    event Guess(address indexed player, string guess, bool correct);
    event Winner(address indexed winner, uint256 prize);
    event Withdrawal(address indexed to, uint256 amount);

    constructor() {
        owner = msg.sender;
        gameState = GameState.NotStarted;
    }

    /// @notice 게임 시작(정답 해시 설정). 기존에 진행 중이면 불가.
    function startGame(bytes32 _answerHash) external onlyOwner {
        if (gameState == GameState.Active) revert GameAlreadyActive();
        if (_answerHash == bytes32(0)) revert AnswerNotSet();

        answerHash = _answerHash;
        winner = address(0);
        gameState = GameState.Active;

        emit GameStarted(_answerHash);
    }

    /// @notice 게임 리셋(새 정답 해시로). 진행 중이면 불가(공정성).
    function restartGame(bytes32 _newAnswerHash) external onlyOwner {
        if (gameState == GameState.Active) revert GameAlreadyActive();
        if (_newAnswerHash == bytes32(0)) revert AnswerNotSet();

        answerHash = _newAnswerHash;
        winner = address(0);
        gameState = GameState.Active;

        emit GameRestarted(_newAnswerHash);
    }

    /// @notice 게임 취소: 남은 잔고를 owner에게 돌리고 종료 (원하면 제거/변경 가능)
    function cancelGame() external onlyOwner nonReentrant {
        if (gameState != GameState.Active) revert GameNotActive();
        gameState = GameState.Ended;

        uint256 prize = address(this).balance;
        if (prize > 0) {
            (bool ok, ) = owner.call{value: prize}("");
            if (!ok) revert TransferFailed();
        }

        emit GameCancelled(prize);
    }

    /// @notice 단어 추측. 맞추면 즉시 종료 + 상금 지급.
    function guessWord(string calldata guess) external payable nonReentrant {
        if (gameState != GameState.Active) revert GameNotActive();
        if (answerHash == bytes32(0)) revert AnswerNotSet();
        if (msg.value != ENTRY_FEE) revert InvalidEntryFee();

        totalPaid[msg.sender] += msg.value;

        bool correct = (keccak256(bytes(guess)) == answerHash);
        emit Guess(msg.sender, guess, correct);

        if (correct) {
            gameState = GameState.Ended;
            winner = msg.sender;

            uint256 prize = address(this).balance;

            // 상금 지급(실패하면 pending에 적립)
            (bool ok, ) = msg.sender.call{value: prize}("");
            if (!ok) {
                pendingWithdrawals[msg.sender] += prize;
            }

            emit Winner(msg.sender, prize);
        }
    }

    /// @notice 전송 실패했을 때(또는 정책상) 보류된 금액 출금
    function withdrawPending() external nonReentrant {
        uint256 amount = pendingWithdrawals[msg.sender];
        if (amount == 0) revert NoPendingWithdrawal();

        pendingWithdrawals[msg.sender] = 0;
        (bool ok, ) = msg.sender.call{value: amount}("");
        if (!ok) revert TransferFailed();

        emit Withdrawal(msg.sender, amount);
    }

    /// @notice 현재 상금(컨트랙트 실제 잔고)
    function prizePool() external view returns (uint256) {
        return address(this).balance;
    }

    /// @notice 게임 상태 조회
    function getGameState() external view returns (GameState state, uint256 pool, address currentWinner) {
        return (gameState, address(this).balance, winner);
    }

    /// @notice 상금 추가(기부 등) - 선택사항
    receive() external payable {}
}
