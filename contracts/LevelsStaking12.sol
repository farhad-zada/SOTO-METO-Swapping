// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {IERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {SafeERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import {IERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ILevels} from "./ILevels.sol";

error Staking__NotAdmin();
error Staking__NotAvailable(uint256 amount);
error Staking__MinStakingAmount(uint256 amount);
error Staking__MaxStakingAmount(uint256 amount);
error Staking__PoolMaxSize(uint256 amount);
error Staking__StatusNotActive();
error Staking__InvalidId();
error Staking__InsufficientFunds(uint balance);
error Staking__ContractLacksBalance();
error Staking__NotEnoughAllowance();

contract LevelsStaking is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    IERC20Upgradeable public token;
    ILevels public levels;

    bool public canActivateStaking = false;

    uint256 public totalStakedToken;

    uint256 public rewardPercentage;
    uint256 public penaltyPercentage;
    uint256 public rewardDeadlineSeconds;

    uint256 public poolMaxSize;
    uint256 public minStakingAmount;
    uint256 public penaltyDivisionStep;

    enum StakeStatus {
        WAITING,
        ACTIVE,
        PAUSED,
        COMPLETED
    }

    StakeStatus public stakeStatus;

    struct Staking {
        uint256 amount;
        uint256 percent;
        uint256 stakedAt;
    }

    struct LevelDetails {
        uint64 level;
        uint256 levelReward;
        uint256 levelMaxStakingAmount;
    }

    mapping(address => bool) private admins;
    mapping(address => Staking[]) private stakings;
    mapping(address => bool) private _nonReentrant;
    ////
    mapping(uint64 => LevelDetails) public levelDetails;

    event Stake(address indexed staker, Staking staking);
    event Claim(address indexed staker, Staking staking);

    // Modifiers

    modifier stakeAvailable(address _staker, uint256 _amount) {
        if (_amount < minStakingAmount)
            revert Staking__MinStakingAmount({amount: _amount});
        if (totalStakedToken + _amount > poolMaxSize)
            revert Staking__PoolMaxSize({amount: totalStakedToken + _amount});
        if (stakeStatus != StakeStatus.ACTIVE)
            revert Staking__StatusNotActive();
        if (
            getUserTotalStakedTokenAmount(_staker) + _amount >
            levelDetails[levels.getLevel(msg.sender)].levelMaxStakingAmount
        ) revert Staking__MaxStakingAmount({amount: _amount});
        _;
    }

    modifier admin() {
        if (!admins[msg.sender]) revert Staking__NotAdmin();
        _;
    }
    modifier nonReentrant() {
        require(!_nonReentrant[msg.sender], "Reentrancy");
        _nonReentrant[msg.sender] = true;
        _;
        _nonReentrant[msg.sender] = false;
    }

    constructor() {
        _disableInitializers();
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    // Init

    function initialize(address _token, address _levels) public initializer {
        __Ownable_init();
        admins[msg.sender] = true;
        token = IERC20Upgradeable(_token);
        levels = ILevels(_levels);

        rewardPercentage = 0;
        penaltyPercentage = 10;
        rewardDeadlineSeconds = 3600 * 24 * 30 * 12; //  a year
        poolMaxSize = 50_000_000 * 10 ** 18;
        minStakingAmount = 20_000 * 10 ** 18;
        penaltyDivisionStep = 30 * 12;
    }

    function stake(
        uint256 _amount
    ) public nonReentrant stakeAvailable(msg.sender, _amount) {
        _stake(_amount, msg.sender, msg.sender, true);
    }

    function claim(uint256 _id) public nonReentrant {
        _claim(msg.sender, _id);
    }

    function _remove(address _staker, uint256 _index) internal {
        delete stakings[_staker][_index];
    }

    function setStakingStatus(StakeStatus status) public onlyOwner {
        require(canActivateStaking, "Staking: not set levelDetails");
        stakeStatus = status;
    }

    function setLevelDetails(
        uint64 _level,
        uint256 _rewardPercent,
        uint256 _maxStakingAmount
    ) public onlyOwner {
        if (!canActivateStaking) {
            canActivateStaking = true;
        }
        levelDetails[_level] = LevelDetails({
            level: _level,
            levelReward: _rewardPercent,
            levelMaxStakingAmount: _maxStakingAmount
        });
    }

    function modifyStakingDetails(
        uint256 _poolMaxSize,
        uint256 _minStakingAmount,
        uint256 _penaltyDivisionSteps
    ) public admin {
        if (_poolMaxSize > 0) {
            poolMaxSize = _poolMaxSize;
        }
        if (_minStakingAmount > 0) {
            _minStakingAmount = _minStakingAmount;
        }
        if (_penaltyDivisionSteps > 0) {
            penaltyDivisionStep = _penaltyDivisionSteps;
        }
    }

    function withdraw(address payable who, uint amount) external onlyOwner {
        SafeERC20Upgradeable.safeTransfer(token, who, amount);
    }

    function setAdmin(address who, bool status) public onlyOwner {
        admins[who] = status;
    }

    function changeLevelsAddress(address _levels) public onlyOwner {
        levels = ILevels(_levels);
    }

    // Helpers

    function _stake(
        uint256 _amount,
        address staker,
        address sponsor,
        bool withLevel
    ) internal stakeAvailable(staker, _amount) {
        uint256 _balance = token.balanceOf(sponsor);
        if (_balance < _amount)
            revert Staking__InsufficientFunds({balance: _balance});

        Staking memory staking = Staking({
            amount: _amount,
            percent: 0,
            stakedAt: block.timestamp
        });

        if (token.allowance(staker, address(this)) < _amount)
            revert Staking__NotEnoughAllowance();
        token.transferFrom(staker, address(this), _amount);
        totalStakedToken += _amount;

        if (withLevel) {
            staking.percent = levelDetails[levels.getLevel(staker)].levelReward;
        } else {
            staking.percent = rewardPercentage;
        }
        stakings[staker].push(staking);
        emit Stake(staker, staking);
    }

    function _claim(address staker, uint256 _id) internal {
        uint256 _balance = token.balanceOf(address(this));
        int256 _index = _getStakeIndexById(staker, _id);
        if (_index < 0) revert Staking__InvalidId();
        uint256 index = uint256(_index);

        (uint256 rewardedAmount, uint256 amount) = _getTransferAmount(
            staker,
            index
        );
        if (_balance < rewardedAmount) revert Staking__ContractLacksBalance();

        totalStakedToken -= amount;

        SafeERC20Upgradeable.safeTransfer(token, staker, rewardedAmount);

        Staking memory staking = stakings[staker][uint256(index)];

        _remove(staker, index);

        emit Claim(staker, staking);
    }

    // State helper funcs

    function _getPenalty(
        uint256 amount,
        uint256 secondsStaked
    ) internal view returns (uint) {
        uint256 chunkSize = rewardDeadlineSeconds / penaltyDivisionStep;
        uint256 chunkPercent = (penaltyPercentage * 10 ** 10) /
            penaltyDivisionStep;
        uint256 percent = penaltyPercentage *
            10 ** 10 -
            ((secondsStaked / chunkSize) * chunkPercent);
        return amount - (((amount * percent) / 100) / 10 ** 10);
    }

    function _getStakeIndexById(
        address _staker,
        uint256 _id
    ) internal view returns (int256) {
        Staking[] memory _stakings = stakings[_staker];
        for (uint256 i = 0; i < _stakings.length; i++) {
            if (_stakings[i].stakedAt == _id) {
                return int(i);
            }
        }
        return -1;
    }

    function _getTransferAmount(
        address _staker,
        uint256 _index
    ) internal view returns (uint256, uint256) {
        Staking memory staking = stakings[_staker][_index];
        uint256 timestamp = block.timestamp;
        uint256 secondsStaked = timestamp - staking.stakedAt;
        if (secondsStaked < rewardDeadlineSeconds) {
            return (_getPenalty(staking.amount, secondsStaked), staking.amount);
        }
        return (
            (staking.amount * staking.percent) / 100 + staking.amount,
            staking.amount
        );
    }

    // State read funcs

    function getMyStakes() public view returns (Staking[] memory) {
        return stakings[msg.sender];
    }

    function getStakes(
        address staker
    ) public view onlyOwner returns (Staking[] memory) {
        return stakings[staker];
    }

    function getUserTotalStakedTokenAmount(
        address staker
    ) public view returns (uint256) {
        Staking[] memory _stakings = stakings[staker];
        uint256 total;
        for (uint i = 0; i < _stakings.length; i++) {
            total += _stakings[i].amount;
        }
        return total;
    }

    function getStakeById(
        uint256 _id
    ) public view returns (Staking memory staking) {
        Staking[] memory _stakings = stakings[msg.sender];
        for (uint256 i = 0; i < _stakings.length; i++) {
            if (_stakings[i].stakedAt == _id) {
                return _stakings[i];
            }
        }
        return Staking(0, 0, 0);
    }

    function getTransferAmount(
        uint256 _id
    ) public view returns (uint256, uint256) {
        uint256 timestamp = block.timestamp;
        Staking memory staking = getStakeById(_id);
        uint256 secondsStaked = timestamp - staking.stakedAt;
        if (secondsStaked < rewardDeadlineSeconds) {
            return (_getPenalty(staking.amount, secondsStaked), staking.amount);
        }
        return (
            (staking.amount * staking.percent) / 100 + staking.amount,
            staking.amount
        );
    }

    function isAdminTrue() public view returns (bool) {
        return admins[msg.sender];
    }

    // Admin functions

    // admin sets specific reward percent for user
    function modifyRewardPersentage(
        address staker,
        uint256 id,
        uint256 newPercent
    ) public admin {
        int256 _index = _getStakeIndexById(staker, id);
        if (_index < 0) revert Staking__InvalidId();
        uint256 index = uint256(_index);

        stakings[staker][index].percent = newPercent;
    }

    // admin sets stake for a specific user
    function setStake(
        address staker,
        uint256 _amount,
        address sponsor,
        bool withLevel
    ) public admin {
        _stake(_amount, staker, sponsor, withLevel);
    }

    // admin claims a specific user
    function claimFor(address staker, uint256 _id) public admin {
        _claim(staker, _id);
    }
}
