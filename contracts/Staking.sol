// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

library SafeMathInt {
    int256 private constant MIN_INT256 = int256(1) << 255;
    int256 private constant MAX_INT256 = ~(int256(1) << 255);

    function mul(int256 a, int256 b) internal pure returns (int256) {
        int256 c = a * b;

        require(c != MIN_INT256 || (a & MIN_INT256) != (b & MIN_INT256));
        require((b == 0) || (c / b == a), "mul overflow");
        return c;
    }

    function div(int256 a, int256 b) internal pure returns (int256) {
        require(b != -1 || a != MIN_INT256);

        return a / b;
    }

    function sub(int256 a, int256 b) internal pure returns (int256) {
        int256 c = a - b;
        require((b >= 0 && c <= a) || (b < 0 && c > a), "sub overflow");
        return c;
    }

    function add(int256 a, int256 b) internal pure returns (int256) {
        int256 c = a + b;
        require((b >= 0 && c >= a) || (b < 0 && c < a), "add overflow");
        return c;
    }

    function abs(int256 a) internal pure returns (int256) {
        require(a != MIN_INT256, "abs overflow");
        return a < 0 ? -a : a;
    }

    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a >= b ? a : b;
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
}

library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    function sub(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

    function div(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        uint256 c = a / b;

        return c;
    }

    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b != 0, "parameter 2 can not be 0");
        return a % b;
    }

    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a >= b ? a : b;
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
}

interface IBEP20 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);

    function totalSupply() external view returns (uint256);

    function balanceOf(address who) external view returns (uint256);

    function allowance(
        address owner,
        address spender
    ) external view returns (uint256);

    function transfer(address to, uint256 value) external returns (bool);

    function approve(address spender, uint256 value) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
}

contract Ownable {
    address private _owner;

    event OwnershipRenounced(address indexed previousOwner);
    event TransferOwnerShip(address indexed previousOwner);

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    constructor() {
        _owner = msg.sender;
    }

    function owner() public view returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(msg.sender == _owner, "Not owner");
        _;
    }

    function renounceOwnership() public onlyOwner {
        emit OwnershipRenounced(_owner);
        _owner = address(0);
    }

    function transferOwnership(address newOwner) public onlyOwner {
        emit TransferOwnerShip(newOwner);
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal {
        require(newOwner != address(0), "Owner can not be 0");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

contract Staking is Ownable {
    using SafeMath for uint256;
    using SafeMathInt for int256;

    IBEP20 public stakingToken;
    IBEP20 public rewardToken;

    struct UserInfo {
        uint256 amount; // How many tokens the user has provided.
        uint256 stakingTime; // The time at which the user staked tokens.
        uint256 rewardClaimed; // The amount of reward claimed by the user.
        uint256 rewardETHClaimed; // The amount of reward claimed by the user.
    }

    struct Pool {
        uint256 maxPoolSize;
        uint256 currentPoolSize;
        uint256 maxContribution;
        uint256 minContribution;
        uint256 apy; // it is in 1000 times, so 1000 means 100%
        uint256 emergencyFees; // it is the fees in percentage, final fees is emergencyFees/1000
        uint256 minLockDays;
        uint256 totalTokenRewards; // total rewards for the pool
        uint256 totalETHRewards; // total rewards for the pool
        uint256 totalRewardsClaimed; // total rewards claimed by the users
        uint256 totalETHRewardsClaimed; // total rewards claimed by the users
        bool poolType; // true for public staking, false for whitelist staking
        bool poolActive;
    }

    // Info of each pool.
    Pool public pool;
    uint256[] public rewardETHTimes;
    uint256[] public rewardTimes;
    bool lock_ = false;

    uint256 public totalRewardsClaimed = 0;
    // Info of each user that stakes tokens.
    mapping(address => UserInfo) public userInfo;
    mapping(uint256 => uint256) public rewardAmount;
    mapping(address => bool) public whitelistedAddress;
    mapping(uint256 => uint256) public rewardCurrentPoolSize;

    // rewardETHAmount is the amount of reward in ETH
    mapping(uint256 => uint256) public rewardETHAmount;
    mapping(uint256 => uint256) public rewardETHCurrentPoolSize;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(
        address indexed user,
        uint256 indexed pid,
        uint256 amount
    );

    constructor(address _tokenAddress, address _rewardTokenAddress) {
        stakingToken = IBEP20(_tokenAddress);
        rewardToken = IBEP20(_rewardTokenAddress);
    }

    modifier lock() {
        require(!lock_, "Process is locked");
        lock_ = true;
        _;
        lock_ = false;
    }

    function addPool(
        uint256 _maxPoolSize,
        uint256 _maxContribution,
        uint256 _emergencyFee,
        uint256 _minContribution,
        uint256 _apy,
        uint256 _minLockDays,
        bool _poolType,
        bool _poolActive
    ) public onlyOwner {
        pool = Pool({
            maxPoolSize: _maxPoolSize,
            currentPoolSize: 0,
            minContribution: _minContribution,
            maxContribution: _maxContribution,
            apy: _apy,
            emergencyFees: _emergencyFee,
            minLockDays: _minLockDays,
            poolType: _poolType,
            poolActive: _poolActive,
            totalRewardsClaimed: 0,
            totalETHRewardsClaimed: 0,
            totalTokenRewards: 0,
            totalETHRewards: 0
        });
    }

    function updateMaxPoolSize(uint256 _maxPoolSize) public onlyOwner {
        require(
            _maxPoolSize >= pool.currentPoolSize,
            "Cannot reduce the max size below the current pool size"
        );
        pool.maxPoolSize = _maxPoolSize;
    }

    function updateMaxContribution(uint256 _maxContribution) public onlyOwner {
        pool.maxContribution = _maxContribution;
    }

    function updateEmergencyFees(uint256 _emergencyFees) public onlyOwner {
        if (pool.currentPoolSize > 0) {
            require(
                _emergencyFees <= pool.emergencyFees,
                "You can't increase the emergency fees when people started staking"
            );
        }
        pool.emergencyFees = _emergencyFees;
    }

    function updateMinLockDays(uint256 _lockDays) public onlyOwner {
        require(
            pool.currentPoolSize == 0,
            "Cannot change lock time after people started staking"
        );
        pool.minLockDays = _lockDays;
    }

    function updateApy(uint256 _apy) public onlyOwner {
        pool.apy = _apy;
    }

    function updatePoolType(bool _poolType) public onlyOwner {
        pool.poolType = _poolType;
    }

    function updatePoolActive(bool _poolActive) public onlyOwner {
        pool.poolActive = _poolActive;
    }

    function updateMinContribution(uint256 _minContribution) public onlyOwner {
        pool.minContribution = _minContribution;
    }

    function addWhitelist(
        address[] memory _whitelistAddresses
    ) public onlyOwner {
        uint256 length = _whitelistAddresses.length;
        require(length <= 200, "Can add only 200 wl at a time");
        for (uint256 i = 0; i < length; i++) {
            address _whitelistAddress = _whitelistAddresses[i];
            whitelistedAddress[_whitelistAddress] = true;
        }
    }

    function addReward(uint256 _amount) public onlyOwner {
        rewardTimes.push(block.timestamp);
        rewardAmount[block.timestamp] = _amount;
        pool.totalTokenRewards = (pool.totalTokenRewards).add(_amount);
        rewardCurrentPoolSize[block.timestamp] = pool.currentPoolSize;
        bool success = rewardToken.transferFrom(
            msg.sender,
            address(this),
            _amount
        );
        require(success, "Transfer failed");
    }

    function addETHReward() public payable onlyOwner {
        uint256 _amount = msg.value;
        rewardETHTimes.push(block.timestamp);
        rewardETHAmount[block.timestamp] = _amount;
        pool.totalETHRewards = (pool.totalETHRewards).add(_amount);
        rewardETHCurrentPoolSize[block.timestamp] = pool.currentPoolSize;
        _sendEther(address(this), _amount);
    }

    function emergencyLock(bool _lock) public onlyOwner {
        lock_ = _lock;
    }

    function stakeTokens(uint256 _amount) public {
        require(pool.poolActive, "Pool is not active");
        require(
            _amount >= pool.minContribution,
            "Amount is less than min contribution"
        );
        require(
            pool.currentPoolSize.add(_amount) <= pool.maxPoolSize,
            "Staking exceeds max pool size"
        );
        require(
            (userInfo[msg.sender].amount).add(_amount) <= pool.maxContribution,
            "Max Contribution exceeds"
        );

        if (pool.poolType == false) {
            require(
                whitelistedAddress[msg.sender],
                "You are not whitelisted for this pool"
            );
        }

        // Sending the claimable tokens to the user
        if (claimableRewards(msg.sender) > 0) {
            _claimRewards();
        }
        if (claimableETHReward(msg.sender) > 0) {
            _claimETHReward();
        }

        bool success = stakingToken.transferFrom(
            msg.sender,
            address(this),
            _amount
        );
        require(success, "Transfer From failed. Please approve the token");

        pool.currentPoolSize = (pool.currentPoolSize).add(_amount);
        uint256 _stakingTime = block.timestamp;
        _amount = _amount.add(userInfo[msg.sender].amount);
        uint256 _rewardClaimed = 0;
        userInfo[msg.sender] = UserInfo({
            amount: _amount,
            stakingTime: _stakingTime,
            rewardClaimed: _rewardClaimed,
            rewardETHClaimed: 0
        });
    }

    function claimableRewards(address _user) public view returns (uint256) {
        uint256 _stakingTime = userInfo[_user].stakingTime;
        // uint256 lockDays = (block.timestamp - _stakingTime) / 1 days;
        // if(lockDays < pool.minLockDays) return 0;
        if (userInfo[_user].amount == 0) return 0;

        uint256 _claimableReward = 0;
        for (uint256 i = 0; i < rewardTimes.length; i++) {
            uint256 _rewardTime = rewardTimes[i];
            uint256 _rewardAmount = rewardAmount[_rewardTime];
            uint256 _rewardCurrentPoolSize = rewardCurrentPoolSize[_rewardTime];
            if (_rewardTime > _stakingTime) {
                uint256 _refundValue = ((userInfo[_user].amount *
                    _rewardAmount) / (_rewardCurrentPoolSize));
                _claimableReward = _claimableReward.add(_refundValue);
            }
        }
        if (userInfo[_user].rewardClaimed >= _claimableReward) return 0;
        return _claimableReward - userInfo[_user].rewardClaimed;
    }

    function claimableNativeRewards(
        address _user
    ) public view returns (uint256) {
        uint256 lockDays = (block.timestamp - userInfo[_user].stakingTime) /
            1 days;
        uint256 _refundValue = ((userInfo[_user].amount * pool.apy * lockDays) /
            (1000 * 365));
        return _refundValue;
    }

    function claimableETHReward(address _user) public view returns (uint256) {
        uint256 _stakingTime = userInfo[_user].stakingTime;
        // uint256 lockDays = (block.timestamp - _stakingTime) / 1 days;
        // if(lockDays < pool.minLockDays) return 0;
        if (userInfo[_user].amount == 0) return 0;

        uint256 _claimableReward = 0;
        for (uint256 i = 0; i < rewardETHTimes.length; i++) {
            uint256 _rewardTime = rewardETHTimes[i];
            uint256 _rewardAmount = rewardETHAmount[_rewardTime];
            uint256 _rewardCurrentPoolSize = rewardETHCurrentPoolSize[
                _rewardTime
            ];
            if (_rewardTime > _stakingTime) {
                uint256 _refundValue = ((userInfo[_user].amount *
                    _rewardAmount) / (_rewardCurrentPoolSize));
                _claimableReward = _claimableReward.add(_refundValue);
            }
        }
        if (userInfo[_user].rewardETHClaimed >= _claimableReward) return 0;
        return _claimableReward - userInfo[_user].rewardETHClaimed;
    }

    function unstakeTokens() public lock {
        require(
            userInfo[msg.sender].amount > 0,
            "You don't have any staked tokens"
        );
        require(
            userInfo[msg.sender].stakingTime > 0,
            "You don't have any staked tokens"
        );
        // check the min lock days is passed or not
        uint256 lockDays = (block.timestamp -
            userInfo[msg.sender].stakingTime) / 1 days;
        require(
            lockDays >= pool.minLockDays,
            "You can't unstake before min lock days"
        );

        uint256 _amount = userInfo[msg.sender].amount;

        // claimethreward
        if (claimableETHReward(msg.sender) > 0) {
            _claimETHReward();
        }

        uint256 _refundValue = claimableRewards(msg.sender);
        uint256 _nativeReward = claimableNativeRewards(msg.sender);
        userInfo[msg.sender].rewardClaimed += _refundValue;
        pool.currentPoolSize = (pool.currentPoolSize).sub(
            userInfo[msg.sender].amount
        );
        pool.totalRewardsClaimed += _refundValue;
        userInfo[msg.sender].amount = 0;
        userInfo[msg.sender].rewardClaimed = 0;
        userInfo[msg.sender].stakingTime = 0;
        userInfo[msg.sender].rewardETHClaimed = 0;

        bool success1 = stakingToken.transfer(msg.sender, _amount);
        bool success2 = stakingToken.transfer(msg.sender, _nativeReward);
        bool success3 = rewardToken.transfer(msg.sender, _refundValue);
        require(success1 && success2 && success3, "Transfer failed");
    }

    function claimRewards() public lock {
        require(
            userInfo[msg.sender].amount > 0,
            "You don't have any staked tokens"
        );
        require(
            userInfo[msg.sender].stakingTime > 0,
            "You don't have any staked tokens"
        );

        uint256 _claimableAmount = claimableRewards(msg.sender);
        require(_claimableAmount > 0, "No rewards to claim"); // check if there is any reward to claim
        userInfo[msg.sender].rewardClaimed += _claimableAmount;
        pool.totalRewardsClaimed += _claimableAmount;
        bool success = rewardToken.transfer(msg.sender, _claimableAmount);
        require(success, "Transfer failed");
    }

    function claimETHReward() public lock {
        require(
            userInfo[msg.sender].amount > 0,
            "You don't have any staked tokens"
        );
        require(
            userInfo[msg.sender].stakingTime > 0,
            "You don't have any staked tokens"
        );

        uint256 _claimableAmount = claimableETHReward(msg.sender);
        require(_claimableAmount > 0, "No rewards to claim"); // check if there is any reward to claim
        pool.totalETHRewardsClaimed += _claimableAmount;
        userInfo[msg.sender].rewardETHClaimed += _claimableAmount;
        _sendEther(msg.sender, _claimableAmount);
    }

    // emergency withdraw function
    function emergencyWithdraw() public lock {
        require(
            userInfo[msg.sender].amount > 0,
            "You don't have any staked tokens"
        );
        require(
            userInfo[msg.sender].stakingTime > 0,
            "You don't have any staked tokens"
        );

        uint256 _amount = userInfo[msg.sender].amount;
        userInfo[msg.sender].amount = 0;
        userInfo[msg.sender].rewardClaimed = 0;
        pool.currentPoolSize = (pool.currentPoolSize).sub(_amount);

        uint256 afterDeductAmount = _amount.sub(
            (_amount * pool.emergencyFees) / 1000
        );
        bool success = stakingToken.transfer(msg.sender, afterDeductAmount);
        require(success, "Transfer failed");
    }

    // send Ether
    function _sendEther(address _to, uint256 _amount) internal {
        (bool success, ) = payable(_to).call{value: _amount}("");
        require(success, "Transfer failed");
    }

    function _claimRewards() private {
        require(
            userInfo[msg.sender].amount > 0,
            "You don't have any staked tokens"
        );
        require(
            userInfo[msg.sender].stakingTime > 0,
            "You don't have any staked tokens"
        );

        uint256 _claimableAmount = claimableRewards(msg.sender);
        require(_claimableAmount > 0, "No rewards to claim"); // check if there is any reward to claim
        userInfo[msg.sender].rewardClaimed += _claimableAmount;
        pool.totalRewardsClaimed += _claimableAmount;
        bool success = rewardToken.transfer(msg.sender, _claimableAmount);
        require(success, "Transfer failed");
    }

    function _claimETHReward() private {
        require(
            userInfo[msg.sender].amount > 0,
            "You don't have any staked tokens"
        );
        require(
            userInfo[msg.sender].stakingTime > 0,
            "You don't have any staked tokens"
        );

        uint256 _claimableAmount = claimableETHReward(msg.sender);
        require(_claimableAmount > 0, "No rewards to claim"); // check if there is any reward to claim
        pool.totalETHRewardsClaimed += _claimableAmount;
        userInfo[msg.sender].rewardETHClaimed += _claimableAmount;
        _sendEther(msg.sender, _claimableAmount);
    }

    // receive Ether
    receive() external payable {}

    // this function is to withdraw BNB sent to this address by mistake
    function withdrawEth() external onlyOwner returns (bool) {
        uint256 balance = address(this).balance;
        (bool success, ) = payable(msg.sender).call{value: balance}("");
        return success;
    }

    // this function is to withdraw BEP20 tokens sent to this address by mistake
    function withdrawBEP20(
        address _tokenAddress
    ) external onlyOwner returns (bool) {
        IBEP20 token = IBEP20(_tokenAddress);
        uint256 balance = token.balanceOf(address(this));
        bool success = token.transfer(msg.sender, balance);
        return success;
    }
}
