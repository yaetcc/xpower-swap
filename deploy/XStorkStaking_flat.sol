// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// contracts/XStorkStaking.sol

/// @title XStorkStaking — 质押挖矿（多池，按秒释放 XSTORK 奖励）
/// @notice owner 创建质押池（指定可质押资产 + 每秒奖励速率），用户 stake/withdraw/claim。
///         奖励按份额累计（accRewardPerShare，1e12 精度）。
contract XStorkStaking {
    address public owner;
    address public rewardToken; // XPR（XPower）

    struct PoolInfo {
        address stakedToken;   // 可质押的资产（xStock 或 LP 凭证）
        uint256 rewardPerSec;  // 每秒释放的 XSTORK（wei）
        uint256 accRewardPerShare; // 1e12 精度
        uint256 lastRewardTime;
        uint256 totalStaked;
        bool active;
    }
    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
    }

    PoolInfo[] public poolInfo;
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;

    event PoolCreated(uint256 indexed pid, address indexed stakedToken, uint256 rewardPerSec);
    event Stake(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event Claim(address indexed user, uint256 indexed pid, uint256 amount);
    event RewardRateUpdated(uint256 indexed pid, uint256 rewardPerSec);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);

    constructor(address _rewardToken) {
        owner = msg.sender;
        rewardToken = _rewardToken;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "XS: not owner");
        _;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    function setOwner(address _owner) external onlyOwner {
        owner = _owner;
    }

    /// @notice 创建质押池；每次调用前先 updatePool 所有旧池（简单起见调用方保证顺序）
    function createPool(address _stakedToken, uint256 _rewardPerSec) external onlyOwner returns (uint256 pid) {
        require(_stakedToken != address(0), "XS: zero token");
        updateAllPools();
        pid = poolInfo.length;
        poolInfo.push(PoolInfo({
            stakedToken: _stakedToken,
            rewardPerSec: _rewardPerSec,
            accRewardPerShare: 0,
            lastRewardTime: block.timestamp,
            totalStaked: 0,
            active: true
        }));
        emit PoolCreated(pid, _stakedToken, _rewardPerSec);
    }

    function setRewardPerSec(uint256 pid, uint256 _rewardPerSec) external onlyOwner {
        updatePool(pid);
        poolInfo[pid].rewardPerSec = _rewardPerSec;
        emit RewardRateUpdated(pid, _rewardPerSec);
    }

    function setActive(uint256 pid, bool _active) external onlyOwner {
        poolInfo[pid].active = _active;
    }

    // ---------- 奖励计算 ----------
    function updateAllPools() public {
        for (uint256 i = 0; i < poolInfo.length; i++) updatePool(i);
    }

    function updatePool(uint256 pid) public {
        PoolInfo storage p = poolInfo[pid];
        if (!p.active) {
            p.lastRewardTime = block.timestamp;
            return;
        }
        if (block.timestamp <= p.lastRewardTime) return;
        if (p.totalStaked == 0) {
            p.lastRewardTime = block.timestamp;
            return;
        }
        uint256 reward = (block.timestamp - p.lastRewardTime) * p.rewardPerSec;
        p.accRewardPerShare += reward * 1e12 / p.totalStaked;
        p.lastRewardTime = block.timestamp;
    }

    function pendingReward(uint256 pid, address user) public view returns (uint256) {
        PoolInfo storage p = poolInfo[pid];
        UserInfo storage u = userInfo[pid][user];
        if (!p.active) return u.amount > 0 ? u.amount * p.accRewardPerShare / 1e12 - u.rewardDebt : 0;
        uint256 acc = p.accRewardPerShare;
        if (block.timestamp > p.lastRewardTime && p.totalStaked > 0) {
            uint256 reward = (block.timestamp - p.lastRewardTime) * p.rewardPerSec;
            acc += reward * 1e12 / p.totalStaked;
        }
        return u.amount * acc / 1e12 - u.rewardDebt;
    }

    // ---------- 用户操作 ----------
    function stake(uint256 pid, uint256 amount) external {
        require(amount > 0, "XS: zero amount");
        PoolInfo storage p = poolInfo[pid];
        require(p.active, "XS: pool inactive");
        updatePool(pid);
        UserInfo storage u = userInfo[pid][msg.sender];
        if (u.amount > 0) {
            uint256 pending = u.amount * p.accRewardPerShare / 1e12 - u.rewardDebt;
            if (pending > 0) _safeReward(msg.sender, pending);
        }
        _safeTransferFrom(p.stakedToken, msg.sender, address(this), amount);
        u.amount += amount;
        u.rewardDebt = u.amount * p.accRewardPerShare / 1e12;
        p.totalStaked += amount;
        emit Stake(msg.sender, pid, amount);
    }

    function withdraw(uint256 pid, uint256 amount) external {
        require(amount > 0, "XS: zero amount");
        PoolInfo storage p = poolInfo[pid];
        UserInfo storage u = userInfo[pid][msg.sender];
        require(u.amount >= amount, "XS: insufficient staked");
        updatePool(pid);
        uint256 pending = u.amount * p.accRewardPerShare / 1e12 - u.rewardDebt;
        if (pending > 0) _safeReward(msg.sender, pending);
        u.amount -= amount;
        u.rewardDebt = u.amount * p.accRewardPerShare / 1e12;
        p.totalStaked -= amount;
        _safeTransfer(p.stakedToken, msg.sender, amount);
        emit Withdraw(msg.sender, pid, amount);
    }

    function claim(uint256 pid) external {
        PoolInfo storage p = poolInfo[pid];
        UserInfo storage u = userInfo[pid][msg.sender];
        updatePool(pid);
        uint256 pending = u.amount * p.accRewardPerShare / 1e12 - u.rewardDebt;
        if (pending > 0) {
            u.rewardDebt = u.amount * p.accRewardPerShare / 1e12;
            _safeReward(msg.sender, pending);
            emit Claim(msg.sender, pid, pending);
        }
    }

    /// @notice 无视奖励直接取出质押资产（奖励归零损失）
    function emergencyWithdraw(uint256 pid) external {
        PoolInfo storage p = poolInfo[pid];
        UserInfo storage u = userInfo[pid][msg.sender];
        uint256 amount = u.amount;
        u.amount = 0;
        u.rewardDebt = 0;
        p.totalStaked -= amount;
        _safeTransfer(p.stakedToken, msg.sender, amount);
        emit EmergencyWithdraw(msg.sender, pid, amount);
    }

    // ---------- 工具 ----------
    function _safeReward(address to, uint256 amount) internal {
        (bool ok, bytes memory d) = rewardToken.call(abi.encodeWithSignature("transfer(address,uint256)", to, amount));
        require(ok && (d.length == 0 || abi.decode(d, (bool))), "XS: reward transfer failed");
    }

    function _safeTransfer(address token, address to, uint256 value) internal {
        (bool ok, bytes memory d) = token.call(abi.encodeWithSignature("transfer(address,uint256)", to, value));
        require(ok && (d.length == 0 || abi.decode(d, (bool))), "XS: transfer failed");
    }

    function _safeTransferFrom(address token, address from, address to, uint256 value) internal {
        (bool ok, bytes memory d) = token.call(abi.encodeWithSignature("transferFrom(address,address,uint256)", from, to, value));
        require(ok && (d.length == 0 || abi.decode(d, (bool))), "XS: transferFrom failed");
    }
}
