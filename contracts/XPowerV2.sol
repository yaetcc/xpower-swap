// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title XPower V2 — XPower 平台奖励币（标准 ERC-20）
/// @notice 总量 2100 万；owner 可增发（预留给质押奖励池）与销毁；XPower-Swap 质押挖矿奖励代币。
contract XPowerV2 {
    string public constant name = "XPower";
    string public constant symbol = "XPR";
    uint8 public constant decimals = 18;
    uint256 public totalSupply;
    address public owner;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Mint(address indexed to, uint256 value);
    event Burn(address indexed from, uint256 value);

    modifier onlyOwner() {
        require(msg.sender == owner, "XPR: not owner");
        _;
    }

    constructor(uint256 _initialSupply) {
        owner = msg.sender;
        if (_initialSupply > 0) {
            balanceOf[msg.sender] = _initialSupply;
            totalSupply = _initialSupply;
            emit Transfer(address(0), msg.sender, _initialSupply);
        }
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
            require(al >= value, "XPR: allowance exceeded");
            allowance[from][msg.sender] = al - value;
        }
        _transfer(from, to, value);
        return true;
    }

    /// @dev 增发（仅 owner）——用于向质押矿池补充奖励
    function mint(address to, uint256 value) external onlyOwner {
        require(to != address(0), "XPR: mint to zero");
        balanceOf[to] += value;
        totalSupply += value;
        emit Mint(to, value);
        emit Transfer(address(0), to, value);
    }

    /// @dev 销毁（任何人可销毁自己的余额）
    function burn(uint256 value) external {
        require(balanceOf[msg.sender] >= value, "XPR: balance");
        balanceOf[msg.sender] -= value;
        totalSupply -= value;
        emit Burn(msg.sender, value);
        emit Transfer(msg.sender, address(0), value);
    }

    function _transfer(address from, address to, uint256 value) internal {
        require(to != address(0), "XPR: transfer to zero");
        require(balanceOf[from] >= value, "XPR: balance");
        balanceOf[from] -= value;
        balanceOf[to] += value;
        emit Transfer(from, to, value);
    }
}
