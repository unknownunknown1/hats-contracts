// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.6;


import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-solidity/contracts/token/ERC20/utils/SafeERC20.sol";
import "openzeppelin-solidity/contracts/utils/math/SafeMath.sol";
import "./HATToken.sol";
import "openzeppelin-solidity/contracts/security/ReentrancyGuard.sol";


contract HATMaster is ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    struct UserInfo {
        uint256 shares;     // The user's share of the pool, based on the LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
    }

    struct PoolUpdate {
        uint256 blockNumber;// update blocknumber
        uint256 totalRewardShares; //totalRewardShares
    }

    struct RewardsSplit {
        //the percentage of the total reward to reward the hacker via vesting contract(claim reported)
        uint256 hackerVestedReward;
        //the percentage of the total reward to reward the hacker(claim reported)
        uint256 hackerReward;
        // the percentage of the total reward to be sent to the committee
        uint256 committeeReward;
        // the percentage of the total reward to be swap to HAT and to be burned
        uint256 swapAndBurn;
        // the percentage of the total reward to be swap to HAT and sent to governance
        uint256 governanceHatReward;
        // the percentage of the total reward to be swap to HAT and sent to the hacker
        uint256 hackerHatReward;
    }

    // Info of each pool.
    struct PoolInfo {
        IERC20 lpToken;
        uint256 poolRewardShares;
        uint256 lastRewardBlock;
        uint256 rewardPerShare;
        uint256 totalUserShares;
        uint256 lastPoolUpdate;
        uint256 balance;
    }

    // Info of each pool.
    struct PoolReward {
        RewardsSplit rewardsSplit;
        uint256[]  rewardsLevels;
        bool committeeCheckIn;
        uint256 vestingDuration;
        uint256 vestingPeriods;
    }

    HATToken public immutable HAT;
    // base unit of reward per block for the combined pools. The actual rewards per block are a multiple of this value
    uint256 public immutable REWARD_PER_BLOCK;
    // the block at which rewards will start to be minted
    uint256 public immutable START_BLOCK;
    // the period after which the multiplier fo the rewards per block is updates - expressed in blocks
    uint256 public immutable MULTIPLIER_PERIOD;

    // Info of each pool.
    PoolInfo[] public poolInfo;
    // map blockNumber to index in globalPoolUpdates
    mapping(uint256 => uint256) public totalPoolSharesUpdatedAtIndex;
    // a history of when pool shares were added or updated
    PoolUpdate[] public globalPoolUpdates;
    mapping(address => uint256) public poolId1; // poolId1 count from 1, subtraction 1 before using with poolInfo
    // Info of each user that stakes LP tokens. pid => user address => info
    mapping (uint256 => mapping (address => UserInfo)) public userInfo;
    //pid -> PoolReward maps pools to outstanding rewards (for hackers)
    mapping (uint256=>PoolReward) internal poolsRewards;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 shares);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 shares);
    event SendReward(address indexed user, uint256 indexed pid, uint256 amount, uint256 requestedAmount);
    event MassUpdatePools(uint256 _fromPid, uint256 _toPid);

    constructor(
        HATToken _hat,
        uint256 _rewardPerBlock,
        uint256 _startBlock,
        uint256 _multiplierPeriod
    ) {
        HAT = _hat;
        REWARD_PER_BLOCK = _rewardPerBlock;
        START_BLOCK = _startBlock;
        MULTIPLIER_PERIOD = _multiplierPeriod;
    }

  /**
   * @dev massUpdatePools - Update reward variables for all pools
   * Be careful of gas spending!
   * @param _fromPid update pools range from this pool id
   * @param _toPid update pools range to this pool id
   */
    function massUpdatePools(uint256 _fromPid, uint256 _toPid) external {
        require(_toPid <= poolInfo.length, "pool range is too big");
        require(_fromPid <= _toPid, "invalid pool range");
        for (uint256 pid = _fromPid; pid < _toPid; ++pid) {
            updatePool(pid);
        }
        emit MassUpdatePools(_fromPid, _toPid);
    }

    function claimReward(uint256 _pid) external {
        _deposit(_pid, 0);
    }

    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        uint256 lastRewardBlock = pool.lastRewardBlock;
        if (block.number <= lastRewardBlock) {
            return;
        }
        uint256 totalUserShares = pool.totalUserShares;
        uint256 lastPoolUpdate = globalPoolUpdates.length-1;
        if (totalUserShares == 0) {
            pool.lastRewardBlock = block.number;
            pool.lastPoolUpdate = lastPoolUpdate;
            return;
        }
        uint256 reward = calcPoolReward(_pid, lastRewardBlock, lastPoolUpdate);
        uint256 amountCanMint = HAT.minters(address(this));
        reward = amountCanMint < reward ? amountCanMint : reward;
        if (reward > 0) {
            HAT.mint(address(this), reward);
        }
        pool.rewardPerShare = pool.rewardPerShare.add(reward.mul(1e12).div(totalUserShares));
        pool.lastRewardBlock = block.number;
        pool.lastPoolUpdate = lastPoolUpdate;
    }

    /**
     * @dev getMultiplier - multiply blocks with relevant multiplier for specific range
     * @param _from range's from block
     * @param _to range's to block
     * will revert if from < START_BLOCK or _to < _from
     */
    function getMultiplier(uint256 _from, uint256 _to) public view returns (uint256 result) {
        uint256[25] memory rewardMultipliers = [uint256(4413), 4413, 8825, 7788, 6873, 6065,
                                            5353, 4724, 4169, 3679, 3247, 2865,
                                            2528, 2231, 1969, 1738, 1534, 1353,
                                            1194, 1054, 930, 821, 724, 639, 0];
        uint256 max = rewardMultipliers.length;
        uint256 i = (_from - START_BLOCK) / MULTIPLIER_PERIOD + 1;
        for (; i < max; i++) {
            uint256 endBlock = MULTIPLIER_PERIOD * i + START_BLOCK;
            if (_to <= endBlock) {
                break;
            }
            result += (endBlock - _from) * rewardMultipliers[i-1];
            _from = endBlock;
        }
        result += (_to - _from) * rewardMultipliers[i > max ? (max-1) : (i-1)];
    }

    function getRewardForBlocksRange(uint256 _from, uint256 _to, uint256 _poolRewardShare, uint256 _totalRewardShares)
    public
    view
    returns (uint256) {
        return getMultiplier(_from, _to).mul(REWARD_PER_BLOCK).mul(_poolRewardShare).div(_totalRewardShares).div(100);
    }

    /**
     * @dev calcPoolReward -
     * calculate rewards for a pool by iterating over the history of totalAllocPoints updates.
     * and sum up all rewards periods from pool.lastRewardBlock till current block number.
     * @param _pid pool id
     * @param _from block starting calculation
     * @param _lastPoolUpdate lastPoolUpdate (globalUpdates length)
     * @return reward
     */
    function calcPoolReward(uint256 _pid, uint256 _from, uint256 _lastPoolUpdate) public view returns(uint256 reward) {
        uint256 poolRewardShares = poolInfo[_pid].poolRewardShares;
        uint256 i = poolInfo[_pid].lastPoolUpdate;
        for (; i < _lastPoolUpdate; i++) {
            uint256 nextUpdateBlock = globalPoolUpdates[i+1].blockNumber;
            reward =
            reward.add(getRewardForBlocksRange(_from,
                                            nextUpdateBlock,
                                            poolRewardShares,
                                            globalPoolUpdates[i].totalRewardShares));
            _from = nextUpdateBlock;
        }
        return reward.add(getRewardForBlocksRange(_from,
                                                block.number,
                                                poolRewardShares,
                                                globalPoolUpdates[i].totalRewardShares));
    }

    function _deposit(uint256 _pid, uint256 _amount) internal nonReentrant {
        require(poolsRewards[_pid].committeeCheckIn, "committee not checked in yet");
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        if (user.shares > 0) {
            uint256 pending = user.shares.mul(pool.rewardPerShare).div(1e12).sub(user.rewardDebt);
            if (pending > 0) {
                safeTransferReward(msg.sender, pending, _pid);
            }
        }
        if (_amount > 0) {
            uint256 lpSupply = pool.balance;
            pool.lpToken.safeTransferFrom(address(msg.sender), address(this), _amount);
            pool.balance = pool.balance.add(_amount);
            uint256 factoredAmount = _amount;
            if (pool.totalUserShares > 0) {
                factoredAmount = pool.totalUserShares.mul(_amount).div(lpSupply);
            }
            user.shares = user.shares.add(factoredAmount);
            pool.totalUserShares = pool.totalUserShares.add(factoredAmount);
        }
        user.rewardDebt = user.shares.mul(pool.rewardPerShare).div(1e12);
        emit Deposit(msg.sender, _pid, _amount);
    }

    function _withdraw(uint256 _pid, uint256 _shares) internal nonReentrant {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.shares >= _shares, "withdraw: not enough user balance");

        updatePool(_pid);
        uint256 pending = user.shares.mul(pool.rewardPerShare).div(1e12).sub(user.rewardDebt);
        if (pending > 0) {
            safeTransferReward(msg.sender, pending, _pid);
        }
        if (_shares > 0) {
            user.shares = user.shares.sub(_shares);
            uint256 amountToWithdraw = _shares.mul(pool.balance).div(pool.totalUserShares);
            pool.balance = pool.balance.sub(amountToWithdraw);
            pool.lpToken.safeTransfer(msg.sender, amountToWithdraw);
            pool.totalUserShares = pool.totalUserShares.sub(_shares);
        }
        user.rewardDebt = user.shares.mul(pool.rewardPerShare).div(1e12);
        emit Withdraw(msg.sender, _pid, _shares);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function _emergencyWithdraw(uint256 _pid) internal {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.shares > 0, "user.shares= 0");
        uint256 factoredBalance = user.shares.mul(pool.balance).div(pool.totalUserShares);
        pool.totalUserShares = pool.totalUserShares.sub(user.shares);
        user.shares = 0;
        user.rewardDebt = 0;
        pool.balance = pool.balance.sub(factoredBalance);
        pool.lpToken.safeTransfer(msg.sender, factoredBalance);
        emit EmergencyWithdraw(msg.sender, _pid, factoredBalance);
    }

    // -------- For manage pool ---------
    function add(uint256 _poolRewardShare, IERC20 _lpToken) internal {
        require(poolId1[address(_lpToken)] == 0, "HATMaster::add: lpToken is already in pool");
        poolId1[address(_lpToken)] = poolInfo.length + 1;
        uint256 lastRewardBlock = block.number > START_BLOCK ? block.number : START_BLOCK;
        uint256 totalRewardShares = (globalPoolUpdates.length == 0) ? _poolRewardShare :
        globalPoolUpdates[globalPoolUpdates.length-1].totalRewardShares.add(_poolRewardShare);

        if (totalPoolSharesUpdatedAtIndex[block.number] != 0) {
           //already update in this block
            globalPoolUpdates[totalPoolSharesUpdatedAtIndex[block.number]-1].totalRewardShares = totalRewardShares;
        } else {
            globalPoolUpdates.push(PoolUpdate({
                blockNumber: block.number,
                totalRewardShares: totalRewardShares
            }));
            totalPoolSharesUpdatedAtIndex[block.number] = globalPoolUpdates.length;
        }

        poolInfo.push(PoolInfo({
            lpToken: _lpToken,
            poolRewardShares: _poolRewardShare,
            lastRewardBlock: lastRewardBlock,
            rewardPerShare: 0,
            totalUserShares: 0,
            lastPoolUpdate: globalPoolUpdates.length-1,
            balance: 0
        }));
    }

    function set(uint256 _pid, uint256 _poolRewardShare) internal {
        updatePool(_pid);
        uint256 totalRewardShares =
        globalPoolUpdates[globalPoolUpdates.length-1].totalRewardShares
        .sub(poolInfo[_pid].poolRewardShares).add(_poolRewardShare);

        if (totalPoolSharesUpdatedAtIndex[block.number] != 0) {
           //already update in this block
            globalPoolUpdates[totalPoolSharesUpdatedAtIndex[block.number]-1].totalRewardShares = totalRewardShares;
        } else {
            globalPoolUpdates.push(PoolUpdate({
                blockNumber: block.number,
                totalRewardShares: totalRewardShares
            }));
            totalPoolSharesUpdatedAtIndex[block.number] = globalPoolUpdates.length;
        }
        poolInfo[_pid].poolRewardShares = _poolRewardShare;
    }

    // Safe HAT transfer function, just in case if rounding error causes pool to not have enough HATs.
    function safeTransferReward(address _to, uint256 _amount, uint256 _pid) internal {
        uint256 hatBalance = HAT.balanceOf(address(this));
        if (_amount > hatBalance) {
            HAT.transfer(_to, hatBalance);
            emit SendReward(_to, _pid, hatBalance, _amount);
        } else {
            HAT.transfer(_to, _amount);
            emit SendReward(_to, _pid, _amount, _amount);
        }
    }
}
