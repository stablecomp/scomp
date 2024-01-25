/**
 * @title ScompTreasuryVesting
 * @notice Vesting of Foundation 2 for SCOMP tokens
 *  ____  _        _     _
 * / ___|| |_ __ _| |__ | | ___  ___ ___  _ __ ___  _ __
 * \___ \| __/ _` | '_ \| |/ _ \/ __/ _ \| '_ ` _ \| '_ \
 *  ___) | || (_| | |_) | |  __/ (_| (_) | | | | | | |_) |
 * |____/ \__\__,_|_.__/|_|\___|\___\___/|_| |_| |_| .__/
 *                                                 |_|
 */

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract ScompFoundationVesting is Ownable {
    using SafeERC20 for ERC20;
    bytes32 public merkleRoot;
    uint256 public immutable vestingStart;
    ERC20 public immutable scomp;

    address public treasury;

    uint16 public constant PERCENTAGE_PRECISION = 10000;
    uint256 public constant INTERVAL = 30 days;

    struct VestingSchedule {
        uint256 totalTokens;
        uint16 initialUnlock;
        uint16 tokensPerInterval;
        uint8 totalIntervals;
    }

    VestingSchedule public vestingSchedule;

    mapping(address => uint256) public claimed;

    event Claimed(address indexed user, uint256 amount, uint256 interval);

    constructor(address _scomp, address _treasury, uint256 _vestingStart) {
        scomp = ERC20(_scomp);
        treasury = _treasury;
        vestingStart = _vestingStart;

        uint256 decimals = 10 ** uint256(scomp.decimals());

        vestingSchedule = VestingSchedule(3937541 * decimals, 500, 500, 20);
    }

    function updateTreasury(address _treasury) external onlyOwner {
        require(_treasury != address(0), "Invalid address");
        require(_treasury != treasury, "Same address");
        claimed[_treasury] = claimed[treasury];
        treasury = _treasury;
    }

    function claim() external {
        require(msg.sender == treasury, "Only treasury allowed");

        require(block.timestamp >= vestingStart, "Vesting not started");

        uint256 currentInterval = (block.timestamp - vestingStart) / INTERVAL;
        uint256 claimAmount = getCurrentClaimableTokens();
        require(claimAmount > 0, "No tokens to claim");

        claimed[msg.sender] += claimAmount;

        emit Claimed(msg.sender, claimAmount, currentInterval);
        scomp.safeTransfer(msg.sender, claimAmount);
    }

    function getClaimedTokens() external view returns (uint256) {
        return claimed[treasury];
    }

    function getInterval() external view returns (uint256) {
        return (block.timestamp - vestingStart) / INTERVAL;
    }

    function getCurrentClaimableTokens() public view returns (uint256) {
        uint256 interval = (block.timestamp - vestingStart) / INTERVAL;

        if (interval >= vestingSchedule.totalIntervals - 1) {
            uint256 claimable = vestingSchedule.totalTokens - claimed[treasury];
            return claimable;
        } else {
            uint256 totalClaimable = ((vestingSchedule.totalTokens *
                vestingSchedule.initialUnlock) +
                (vestingSchedule.totalTokens *
                    vestingSchedule.tokensPerInterval *
                    interval)) / PERCENTAGE_PRECISION;
            uint256 finalAmount = totalClaimable - claimed[treasury];
            return finalAmount;
        }
    }

    function getContractTokenBalance() external view returns (uint256) {
        return scomp.balanceOf(address(this));
    }

    function withdrawTokens(address token, uint256 amount) external onlyOwner {
        ERC20(token).safeTransfer(msg.sender, amount);
    }
}
