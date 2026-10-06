// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// contracts/XStorkPair.sol

/// @title XStorkPair — xstork AMM 交易对（Uniswap V2 风格，恒定乘积）
/// @notice 持有 token0/token1 双储备；LP 凭证 ERC20；0.3% 手续费全归流动性提供者。
contract XStorkPair {
    string public name = "XStork LP";
    string public symbol = "XLP";
    uint8 public constant decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    address public factory;
    address public token0;
    address public token1;

    uint112 private reserve0;
    uint112 private reserve1;
    uint32 private blockTimestampLast;

    uint256 public price0CumulativeLast;
    uint256 public price1CumulativeLast;
    uint256 public kLast;

    uint256 private unlocked = 1;
    uint256 public constant MINIMUM_LIQUIDITY = 1000;

    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    event Swap(address indexed sender, uint amount0In, uint amount1In, uint amount0Out, uint amount1Out, address indexed to);
    event Sync(uint112 reserve0, uint112 reserve1);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    modifier lock() {
        require(unlocked == 1, "XP: locked");
        unlocked = 0;
        _;
        unlocked = 1;
    }

    constructor(address _token0, address _token1, address _factory) {
        token0 = _token0;
        token1 = _token1;
        factory = _factory;
    }

    function getReserves() public view returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast) {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
        _blockTimestampLast = blockTimestampLast;
    }

    function _safeTransfer(address token, address to, uint256 value) private {
        (bool ok, bytes memory d) = token.call(abi.encodeWithSignature("transfer(address,uint256)", to, value));
        require(ok && (d.length == 0 || abi.decode(d, (bool))), "XP: transfer failed");
    }

    // ---------- LP 凭证（ERC20） ----------
    function _mint(address to, uint256 value) internal {
        totalSupply += value;
        balanceOf[to] += value;
        emit Transfer(address(0), to, value);
    }

    function _burn(address from, uint256 value) internal {
        balanceOf[from] -= value;
        totalSupply -= value;
        emit Transfer(from, address(0), value);
    }

    function transfer(address to, uint256 value) external returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    function approve(address spender, uint256 value) external returns (bool) {
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) external returns (bool) {
        uint256 al = allowance[from][msg.sender];
        if (al != type(uint256).max) {
            require(al >= value, "XP: allowance exceeded");
            allowance[from][msg.sender] = al - value;
        }
        _transfer(from, to, value);
        return true;
    }

    function _transfer(address from, address to, uint256 value) internal {
        require(balanceOf[from] >= value, "XP: balance");
        balanceOf[from] -= value;
        balanceOf[to] += value;
        emit Transfer(from, to, value);
    }

    // ---------- 流动性 ----------
    function _mintFee(uint112 _r0, uint112 _r1) private returns (bool) {
        address feeTo = XStorkFactory(factory).feeTo();
        bool feeOn = feeTo != address(0);
        uint256 _kLast = kLast;
        if (feeOn) {
            if (_kLast != 0) {
                uint256 rootK = sqrt(uint256(_r0) * uint256(_r1));
                uint256 rootKLast = sqrt(_kLast);
                if (rootK > rootKLast) {
                    uint256 numerator = totalSupply * (rootK - rootKLast);
                    uint256 denominator = rootK * 5 + rootKLast;
                    uint256 liquidity = numerator / denominator;
                    if (liquidity > 0) _mint(feeTo, liquidity);
                }
            }
        } else if (_kLast != 0) {
            kLast = 0;
        }
        return true;
    }

    /// @notice 首次添加流动性（调用方需先转账两种代币到本合约）
    function mint(address to) external lock returns (uint256 liquidity) {
        (uint112 _r0, uint112 _r1,) = getReserves();
        uint256 b0 = IERC20Minimal(token0).balanceOf(address(this));
        uint256 b1 = IERC20Minimal(token1).balanceOf(address(this));
        uint256 a0 = b0 - _r0;
        uint256 a1 = b1 - _r1;
        uint256 _totalSupply = totalSupply;
        if (_totalSupply == 0) {
            liquidity = sqrt(a0 * a1) - MINIMUM_LIQUIDITY;
            _mint(address(0), MINIMUM_LIQUIDITY);
        } else {
            liquidity = min(a0 * _totalSupply / _r0, a1 * _totalSupply / _r1);
        }
        require(liquidity > 0, "XP: zero liquidity");
        _mint(to, liquidity);
        _update(b0, b1);
        if (XStorkFactory(factory).feeTo() != address(0)) kLast = uint256(reserve0) * reserve1;
        emit Mint(to, a0, a1);
    }

    /// @notice 移除流动性（调用方需先转账 LP 凭证到本合约）
    function burn(address to) external lock returns (uint256 amount0, uint256 amount1) {
        (uint112 _r0, uint112 _r1,) = getReserves();
        address _token0 = token0;
        address _token1 = token1;
        uint256 b0 = IERC20Minimal(_token0).balanceOf(address(this));
        uint256 b1 = IERC20Minimal(_token1).balanceOf(address(this));
        uint256 liquidity = balanceOf[address(this)];
        _mintFee(_r0, _r1);
        uint256 _totalSupply = totalSupply;
        amount0 = liquidity * b0 / _totalSupply;
        amount1 = liquidity * b1 / _totalSupply;
        require(amount0 > 0 && amount1 > 0, "XP: zero amounts");
        _burn(address(this), liquidity);
        _safeTransfer(_token0, to, amount0);
        _safeTransfer(_token1, to, amount1);
        b0 = IERC20Minimal(_token0).balanceOf(address(this));
        b1 = IERC20Minimal(_token1).balanceOf(address(this));
        _update(b0, b1);
        if (XStorkFactory(factory).feeTo() != address(0)) kLast = uint256(reserve0) * reserve1;
        emit Burn(msg.sender, amount0, amount1, to);
    }

    /// @notice 兑换（调用方需先转账输入代币到本合约）
    function swap(uint256 amount0Out, uint256 amount1Out, address to) external lock {
        require(amount0Out > 0 || amount1Out > 0, "XP: zero out");
        (uint112 _r0, uint112 _r1,) = getReserves();
        require(amount0Out < _r0 && amount1Out < _r1, "XP: insufficient reserve");
        uint256 b0 = IERC20Minimal(token0).balanceOf(address(this)) - amount0Out;
        uint256 b1 = IERC20Minimal(token1).balanceOf(address(this)) - amount1Out;
        require(b0 * b1 >= uint256(_r0) * _r1, "XP: K");
        _safeTransfer(token0, to, amount0Out);
        _safeTransfer(token1, to, amount1Out);
        _update(b0, b1);
        emit Swap(msg.sender, b0 > _r0 ? b0 - _r0 : 0, b1 > _r1 ? b1 - _r1 : 0, amount0Out, amount1Out, to);
    }

    function sync() external lock {
        _update(IERC20Minimal(token0).balanceOf(address(this)), IERC20Minimal(token1).balanceOf(address(this)));
    }

    function _update(uint256 b0, uint256 b1) private {
        require(b0 <= type(uint112).max && b1 <= type(uint112).max, "XP: overflow");
        reserve0 = uint112(b0);
        reserve1 = uint112(b1);
        blockTimestampLast = uint32(block.timestamp % 2 ** 32);
        emit Sync(reserve0, reserve1);
    }

    // ---------- 工具 ----------
    function min(uint256 a, uint256 b) internal pure returns (uint256) { return a < b ? a : b; }
    function sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) { z = x; x = (y / x + x) / 2; }
        } else if (y != 0) { z = 1; }
    }
}

interface IERC20Minimal {
    function balanceOf(address) external view returns (uint256);
}

// contracts/XStorkFactory.sol

/// @title XStorkFactory — 创建并登记 xstork AMM 交易对
contract XStorkFactory {
    address public owner;
    address public feeTo; // 协议手续费接收（0 表示关闭）

    mapping(address => mapping(address => address)) public getPair;
    address[] public allPairs;

    event PairCreated(address indexed token0, address indexed token1, address pair, uint allPairsLength);
    event FeeToUpdated(address indexed feeTo);

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "XF: not owner");
        _;
    }

    function allPairsLength() external view returns (uint) {
        return allPairs.length;
    }

    function setOwner(address _owner) external onlyOwner {
        owner = _owner;
    }

    function setFeeTo(address _feeTo) external onlyOwner {
        feeTo = _feeTo;
        emit FeeToUpdated(_feeTo);
    }

    /// @notice 创建交易对；token 自动排序，重复创建直接返回已有对
    function createPair(address tokenA, address tokenB) external returns (address pair) {
        (address t0, address t1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(t0 != address(0), "XF: zero token");
        require(t0 != t1, "XF: identical tokens");
        require(getPair[t0][t1] == address(0), "XF: pair exists");

        XStorkPair _pair = new XStorkPair(t0, t1, address(this));
        pair = address(_pair);
        getPair[t0][t1] = pair;
        getPair[t1][t0] = pair;
        allPairs.push(pair);
        emit PairCreated(t0, t1, pair, allPairs.length);
    }
}
