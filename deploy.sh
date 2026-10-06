#!/usr/bin/env bash
# XPower · Swap & DeFi — 一键部署脚本（X Layer 196）
# 用法:  export PRIVATE_KEY=0x你的私钥;  bash deploy.sh
set -e
export PATH="$HOME/.foundry/bin:$PATH"
cd "$(dirname "$0")"

if [ -z "$PRIVATE_KEY" ]; then echo "请先 export PRIVATE_KEY=0x你的私钥"; exit 1; fi
RPC="${RPC:-https://rpc.xlayer.tech}"

echo "== 编译 =="
forge build --quiet

echo "== 1/4 XPower 奖励币 (XPR · 2100万) =="
XSTORK=$(forge create contracts/XPower.sol:XPower --constructor-args "21000000000000000000000000" --rpc-url "$RPC" --private-key "$PRIVATE_KEY" --json | python3 -c "import sys,json;print(json.load(sys.stdin)['deployedTo'])")
echo "XSTORK = $XSTORK"

echo "== 2/4 XStorkFactory =="
FACTORY=$(forge create contracts/XStorkFactory.sol:XStorkFactory --rpc-url "$RPC" --private-key "$PRIVATE_KEY" --json | python3 -c "import sys,json;print(json.load(sys.stdin)['deployedTo'])")
echo "FACTORY = $FACTORY"

echo "== 3/4 XStorkRouter =="
ROUTER=$(forge create contracts/XStorkRouter.sol:XStorkRouter --constructor-args "$FACTORY" --rpc-url "$RPC" --private-key "$PRIVATE_KEY" --json | python3 -c "import sys,json;print(json.load(sys.stdin)['deployedTo'])")
echo "ROUTER = $ROUTER"

echo "== 4/4 XStorkStaking =="
STAKING=$(forge create contracts/XStorkStaking.sol:XStorkStaking --constructor-args "$XSTORK" --rpc-url "$RPC" --private-key "$PRIVATE_KEY" --json | python3 -c "import sys,json;print(json.load(sys.stdin)['deployedTo'])")
echo "STAKING = $STAKING"

cat <<EOF

========== 部署完成 ==========
XPR      奖励币 : $XSTORK (2100万 XPR)
FACTORY  交易对工厂 : $FACTORY
ROUTER   兑换路由 : $ROUTER
STAKING  质押挖矿 : $STAKING

接下来（手动）:
1) 给质押池注入奖励: cast send --private-key \$PRIVATE_KEY --rpc-url $RPC $XSTORK "transfer(address,uint256)" $STAKING <2100万XPR=21000000000000000000000000>
2) 前端「合约配置」填入以上 4 个地址并保存
3) 「资产」页粘贴 xStock 资产地址（如 xTSLA/xNVDA）→ 即可 Swap / 加流动性 / 质押
================================
EOF
