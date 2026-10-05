// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./XStorkPair.sol";

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
