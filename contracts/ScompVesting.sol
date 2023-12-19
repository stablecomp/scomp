// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract ScompVesting is Ownable {
    using SafeERC20 for ERC20;
    bytes32 public merkleRoot;
    uint256 public immutable vestingStart;
    ERC20 public immutable scomp;

    uint16 public constant PERCENTAGE_PRECISION = 10000;
    uint256 public constant INTERVAL = 30 days;

    struct VestingSchedule {
        uint256 totalTokens; // Total tokens to be vested
        uint16 initialUnlock; // Percentage of tokens to be unlocked initially
        uint16 tokensPerInterval; // Percentage of tokens to be unlocked per interval
        uint8 startDelay; // In months
        uint8 totalIntervals; // In months
    }

    mapping(uint8 => VestingSchedule) public vestingSchedules;

    // record of claimed tokens for each address for each vesting schedule.
    mapping(address => mapping(uint8 => uint256)) public claimed;

    event Claimed(
        address indexed user,
        uint256 amount,
        uint256 interval,
        uint8 vestingSchedule
    );

    constructor(address _scomp, bytes32 merkleRoot_, uint256 _vestingStart) {
        scomp = ERC20(_scomp);
        merkleRoot = merkleRoot_;
        vestingStart = _vestingStart;

        uint256 decimals = 10 ** uint256(scomp.decimals());
        vestingSchedules[0] = VestingSchedule(
            12000000 * decimals, // 12,000,000 tokens
            1500, // 15% initial unlock
            607, // ~6.07% monthly distribution
            0, // 0 months start delay
            15 // 15 total months
        );

        vestingSchedules[1] = VestingSchedule(
            12000000 * decimals, // 12,000,000 tokens
            1500, // 15% initial unlock
            772, // ~7.72% monthly distribution
            0, // 0 months start delay
            12 // 12 total months
        );

        vestingSchedules[2] = VestingSchedule(
            12000000 * decimals, // 12,000,000 tokens
            1500, // 15% initial unlock
            1062, // ~10.62% monthly distribution
            0, // 0 months start delay
            9 // 9 total months
        );

        vestingSchedules[3] = VestingSchedule(
            26690910 * decimals, // 26,690,910 tokens
            0, // 0% initial unlock
            1000, // ~10% monthly distribution
            2, // 1 months start delay
            12 // 12 total months (10 months vesting + 2 month delay)
        );

        vestingSchedules[4] = VestingSchedule(
            19104000 * decimals, // 19,104,000 tokens
            0, // 0% initial unlock
            909, // ~9.09% monthly distribution
            1, // 1 months start delay
            12 // 12 total months (11 months vesting + 1 month delay)
        );

        vestingSchedules[5] = VestingSchedule(
            100000 * decimals, // 100,000 tokens
            400, // 4% initial unlock
            872, // ~8.72% monthly distribution
            0, // 0 months start delay
            12 // 12 total months (12 months vesting)
        );

        vestingSchedules[6] = VestingSchedule(
            39166800 * decimals, // 39,166,800 tokens
            0, // 0% initial unlock
            212, // ~2.12% monthly distribution
            1, // 1 months start delay
            48 // 48 total months (47 months vesting + 1 month delay)
        );

        vestingSchedules[7] = VestingSchedule(
            69000000 * decimals, // 69,000,000 tokens
            0, // 0% initial unlock
            500, // ~5% monthly distribution
            4, // 4 months start delay
            24 // 24 total months (20 months vesting + 4 month delay)
        );
    }

    function updateMerkleRoot(bytes32 merkleRoot_) external onlyOwner {
        merkleRoot = merkleRoot_;
    }

    function claim(
        uint8 vestingSchedule,
        uint256 totalTokens,
        bytes32[] calldata merkleProof
    ) external {
        bytes32 leaf = keccak256(
            bytes.concat(
                keccak256(abi.encode(msg.sender, vestingSchedule, totalTokens))
            )
        );

        require(
            MerkleProof.verify(merkleProof, merkleRoot, leaf),
            "Invalid Merkle proof"
        );

        require(
            block.timestamp >=
                vestingStart +
                    vestingSchedules[vestingSchedule].startDelay *
                    INTERVAL,
            "Vesting not started"
        );

        uint256 currentInterval = (block.timestamp - vestingStart) / INTERVAL;
        uint256 claimAmount = getCurrentClaimableTokens(
            msg.sender,
            vestingSchedule,
            totalTokens
        );
        require(claimAmount > 0, "No tokens to claim");

        claimed[msg.sender][vestingSchedule] += claimAmount;

        emit Claimed(msg.sender, claimAmount, currentInterval, vestingSchedule);
        scomp.safeTransfer(msg.sender, claimAmount);
    }

    function getVestingDetails(
        uint8 vestingSchedule
    )
        external
        view
        returns (
            uint256 totalTokens,
            uint16 initialUnlock,
            uint16 tokensPerInterval,
            uint8 startDelay,
            uint8 totalIntervals
        )
    {
        VestingSchedule memory schedule = vestingSchedules[vestingSchedule];
        return (
            schedule.totalTokens,
            schedule.initialUnlock,
            schedule.tokensPerInterval,
            schedule.startDelay,
            schedule.totalIntervals
        );
    }

    function getClaimedTokens(
        address user,
        uint8 vestingSchedule
    ) external view returns (uint256) {
        return claimed[user][vestingSchedule];
    }

    function getInterval() external view returns (uint256) {
        return (block.timestamp - vestingStart) / INTERVAL;
    }

    function getCurrentClaimableTokens(
        address user,
        uint8 vestingSchedule,
        uint256 totalTokens
    ) public view returns (uint256) {
        uint256 interval = (block.timestamp - vestingStart) / INTERVAL;
        uint256 currentInterval = vestingSchedules[vestingSchedule].startDelay >
            0
            ? interval - (vestingSchedules[vestingSchedule].startDelay - 1)
            : interval;

        if (interval >= vestingSchedules[vestingSchedule].totalIntervals - 1) {
            uint256 claimable = totalTokens - claimed[user][vestingSchedule];
            return claimable;
        } else {
            uint256 totalClaimable = ((totalTokens *
                vestingSchedules[vestingSchedule].initialUnlock) +
                (totalTokens *
                    vestingSchedules[vestingSchedule].tokensPerInterval *
                    currentInterval)) / PERCENTAGE_PRECISION;
            uint256 finalAmount = totalClaimable -
                claimed[user][vestingSchedule];
            return finalAmount;
        }
    }

    function getContractTokenBalance() external view returns (uint256) {
        return scomp.balanceOf(address(this));
    }
}
