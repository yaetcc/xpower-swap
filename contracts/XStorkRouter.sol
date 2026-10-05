// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./XStorkFactory.sol";
import "./XStorkPair.sol";

/// @title XStorkRouter — xstork 兑换/流动性路由（Uniswap V2 风格）
/// @notice 不依赖 CREATE2，交易对一律通过 factory.getPair 解析。
contract XStorkRouter {
    address public factory;
    address public WETH; // 未启用原生代币路由，保留为 0

    constructor(address _factory) {
        factory = _factory;
    }

    modifier ensure(uint deadline) {
        require(deadline >= block.timestamp, "XR: expired");
        _;
    }

    function _sortTokens(address a, address b) internal pure returns (address t0, address t1) {
        require(a != b, "XR: identical");
        (t0, t1) = a < b ? (a, b) : (b, a);
        require(t0 != address(0), "XR: zero");
    }

    function _pairFor(address a, address b) internal view returns (XStorkPair pair) {
        pair = XStorkPair(XStorkFactory(factory).getPair(a, b));
        require(address(pair) != address(0), "XR: no pair");
    }

    function _getReserves(address a, address b) internal view returns (uint r0, uint r1) {
        (address t0,) = _sortTokens(a, b);
        (uint112 _r0, uint112 _r1,) = _pairFor(a, b).getReserves();
        (r0, r1) = a == t0 ? (_r0, _r1) : (_r1, _r0);
    }

    function _quote(uint a, uint r0, uint r1) internal pure returns (uint) {
        require(r0 > 0, "XR: zero reserve");
        return a * r1 / r0;
    }

    function _addLiquidity(address a, address b, uint ad, uint bd, uint amin, uint bmin)
        internal returns (uint amountA, uint amountB)
    {
        if (XStorkFactory(factory).getPair(a, b) == address(0)) {
            XStorkFactory(factory).createPair(a, b);
        }
        (uint r0, uint r1) = _getReserves(a, b);
        if (r0 == 0 && r1 == 0) {
            (amountA, amountB) = (ad, bd);
        } else {
            uint bOpt = _quote(ad, r0, r1);
            if (bOpt <= bd) {
                require(bOpt >= bmin, "XR: insufficient B amount");
                (amountA, amountB) = (ad, bOpt);
            } else {
                uint aOpt = _quote(bd, r1, r0);
                require(aOpt <= ad && aOpt >= amin, "XR: insufficient A amount");
                (amountA, amountB) = (aOpt, bd);
            }
        }
    }

    // ---------- 流动性 ----------
    function addLiquidity(address tokenA, address tokenB, uint amountADesired, uint amountBDesired,
        uint amountAMin, uint amountBMin, address to, uint deadline) external ensure(deadline) returns (uint amountA, uint amountB, uint liquidity)
    {
        (amountA, amountB) = _addLiquidity(tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin);
        _safeTransferFrom(tokenA, msg.sender, address(_pairFor(tokenA, tokenB)), amountA);
        _safeTransferFrom(tokenB, msg.sender, address(_pairFor(tokenA, tokenB)), amountB);
        liquidity = _pairFor(tokenA, tokenB).mint(to);
    }

    function removeLiquidity(address tokenA, address tokenB, uint liquidity, uint amountAMin, uint amountBMin,
        address to, uint deadline) external ensure(deadline) returns (uint amountA, uint amountB)
    {
        address pair = address(_pairFor(tokenA, tokenB));
        _safeTransferFrom(pair, msg.sender, pair, liquidity);
        (uint amount0, uint amount1) = XStorkPair(pair).burn(to);
        (address t0,) = _sortTokens(tokenA, tokenB);
        (amountA, amountB) = tokenA == t0 ? (amount0, amount1) : (amount1, amount0);
        require(amountA >= amountAMin && amountB >= amountBMin, "XR: slippage");
    }

    // ---------- 兑换 ----------
    function _getAmountOut(uint amountIn, uint rIn, uint rOut) internal pure returns (uint) {
        require(amountIn > 0, "XR: zero in");
        require(rIn > 0 && rOut > 0, "XR: zero reserve");
        uint amountInWithFee = amountIn * 997;
        uint numerator = amountInWithFee * rOut;
        uint denominator = rIn * 1000 + amountInWithFee;
        return numerator / denominator;
    }

    function getAmountOut(uint amountIn, uint rIn, uint rOut) external pure returns (uint) {
        return _getAmountOut(amountIn, rIn, rOut);
    }

    function getAmountsOut(uint amountIn, address[] calldata path) public view returns (uint[] memory amounts) {
        amounts = new uint[](path.length);
        amounts[0] = amountIn;
        for (uint i = 1; i < path.length; i++) {
            (uint r0, uint r1) = _getReserves(path[i - 1], path[i]);
            amounts[i] = _getAmountOut(amounts[i - 1], r0, r1);
        }
    }

    function _getAmountIn(uint amountOut, uint rIn, uint rOut) internal pure returns (uint) {
        require(amountOut > 0, "XR: zero out");
        require(rIn > 0 && rOut > 0, "XR: zero reserve");
        uint numerator = rIn * amountOut * 1000;
        uint denominator = (rOut - amountOut) * 997;
        return (numerator / denominator) + 1;
    }

    function getAmountIn(uint amountOut, uint rIn, uint rOut) external pure returns (uint) {
        return _getAmountIn(amountOut, rIn, rOut);
    }

    function getAmountsIn(uint amountOut, address[] calldata path) public view returns (uint[] memory amounts) {
        amounts = new uint[](path.length);
        amounts[amounts.length - 1] = amountOut;
        for (uint i = path.length - 1; i > 0; i--) {
            (uint r0, uint r1) = _getReserves(path[i - 1], path[i]);
            amounts[i - 1] = _getAmountIn(amounts[i], r0, r1);
        }
    }

    function swapExactTokensForTokens(uint amountIn, uint amountOutMin, address[] calldata path,
        address to, uint deadline) external ensure(deadline) returns (uint[] memory amounts)
    {
        amounts = getAmountsOut(amountIn, path);
        require(amounts[amounts.length - 1] >= amountOutMin, "XR: insufficient out");
        _swap(amounts, path, to);
    }

    function swapTokensForExactTokens(uint amountOut, uint amountInMax, address[] calldata path,
        address to, uint deadline) external ensure(deadline) returns (uint[] memory amounts)
    {
        amounts = getAmountsIn(amountOut, path);
        require(amounts[0] <= amountInMax, "XR: excessive in");
        _swap(amounts, path, to);
    }

    function _swap(uint[] memory amounts, address[] memory path, address _to) internal {
        for (uint i = 0; i < path.length - 1; i++) {
            (address t0, address t1) = _sortTokens(path[i], path[i + 1]);
            XStorkPair pair = _pairFor(path[i], path[i + 1]);
            uint amountIn = amounts[i];
            uint amountOut = amounts[i + 1];
            _safeTransferFrom(path[i], msg.sender, address(pair), amountIn);
            (uint amt0Out, uint amt1Out) = path[i] == t0 ? (uint(0), amountOut) : (amountOut, uint(0));
            address to = (i == path.length - 2) ? _to : address(_pairFor(path[i + 1], path[i + 2]));
            pair.swap(amt0Out, amt1Out, to);
        }
    }

    // ---------- 工具 ----------
    function _safeTransferFrom(address token, address from, address to, uint value) internal {
        (bool ok, bytes memory d) = token.call(abi.encodeWithSignature("transferFrom(address,address,uint256)", from, to, value));
        require(ok && (d.length == 0 || abi.decode(d, (bool))), "XR: transferFrom failed");
    }

    receive() external payable {}
}
