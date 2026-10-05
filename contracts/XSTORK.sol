// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title XSTORK — xstork 平台奖励币（ERC20）
/// @notice 总量 2100 万，owner 可 mint（预留给质押奖励池）；质押挖矿的奖励代币。
contract XSTORK {
    string public name = "XSTORK";
    string public symbol = "XSTORK";
    uint8 public constant decimals = 18;
    uint256 public totalSupply;
    address public owner;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor(uint256 _initialSupply) {
        owner = msg.sender;
        if (_initialSupply > 0) {
            balanceOf[msg.sender] = _initialSupply;
            totalSupply = _initialSupply;
        }
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "XSTORK: not owner");
        _;
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
            require(al >= value, "XSTORK: allowance exceeded");
            allowance[from][msg.sender] = al - value;
        }
        _transfer(from, to, value);
        return true;
    }

    function mint(address to, uint256 value) external onlyOwner {
        balanceOf[to] += value;
        totalSupply += value;
        emit Transfer(address(0), to, value);
    }

    function burn(uint256 value) external {
        require(balanceOf[msg.sender] >= value, "XSTORK: balance");
        balanceOf[msg.sender] -= value;
        totalSupply -= value;
        emit Transfer(msg.sender, address(0), value);
    }

    function _transfer(address from, address to, uint256 value) internal {
        require(balanceOf[from] >= value, "XSTORK: balance");
        balanceOf[from] -= value;
        balanceOf[to] += value;
        emit Transfer(from, to, value);
    }
}
