# XPower Swap ⚡

**XLayer 上的 xStock 股票资产 DEX —— 兑换 · 流动性 · 质押 Farm · 一键发盘**

XPower Swap 是一个运行在 **X Layer（chainId 196，OKX 以太坊 L2）** 上的去中心化交易所（DEX）与发射台一体平台。用户可以用 **OKB 与全部 63 个 xStock 股票资产**（AAPL、TSLA、NVDA、META、COIN 等 wrapped 股票代币）自由兑换、添加流动性，并可通过「一键起盘」部署自己的交易对与矿池。

**线上地址：https://xpower.world** · 源码仓库：`yaetcc/xpower-swap`

---

## ✨ 核心功能

| 页面 | 能力 |
|---|---|
| **兑换 Swap** | OKB ↔ XPR ↔ xStock 全资产兑换 · 实时报价 / 价格影响 / 滑点保护（0.1–10% 自定义）· 25/50/75/MAX 快捷比例 · 5 节点 RPC 自动容灾 |
| **流动性 Pool** | 一键添加 / 移除流动性 · 全部交易对浏览器（双币 Logo、储备、价格）· 池 TVL 估算 · LP 凭证管理 |
| **质押 Farm** | Owner 一键创建质押池（指定任意 ERC20 + 每秒奖励）· 质押 / 领取 / 紧急提取 · 分红卡（XPRS 持币分红 XPR）· 奖励余额分池显示 |
| **资产 Assets** | 63 个 xStock 资产名录（官方 Logo）· OKB / XPR / XPRS 平台币 · Multicall3 批量秒读余额 · 自定义资产添加 |
| **一键起盘 Launch** | 部署 XPR 平台币 → Factory / Router / Staking 四合约一步到位 · 公开分享链接携带全部合约地址（`?fc=&rt=&st=&xp=&xr=`） |

## 🔗 合约地址（X Layer · chainId 196）

| 合约 | 地址 |
|---|---|
| **Factory**（交易对工厂） | `0xfdBA35dbB9a7a2c01dA3aafD6E6900e9e1838805` |
| **Router**（路由） | `0xA6086c26C449f58047DD94487c94796D684cB442` |
| **Staking**（矿池） | `0x9C2e0c1ca789B6582cD05BefE1f695b8E55cb955` |
| **XPR**（平台奖励币） | `0xcd76b6223b045fc97b04ef0Ef427a0a5a0561BCF` |
| **XPRS**（分红币） | `0xcfc2e529309dCf29a9BBEa90D6fd33Fc365DEEeE` |

> 合约源码见 `contracts/`（Foundry），已开源并可在区块浏览器验证。链上速览：`https://web3.okx.com/zh-hans/explorer/x-layer/evm/`

## 🚀 快速开始

```bash
# 本地预览（单文件自包含，无需构建）
cd XPower-Swap
python3 -m http.server 8080
# 打开 http://localhost:8080
```

```bash
# 合约层（Foundry）
forge build          # 编译
forge test           # 测试
forge script script/Deploy.s.sol --rpc-url $RPC --broadcast   # 部署
```

## 🛠 技术栈

- **前端**：单文件 HTML5（`XPower Swap DApp.html`）· ethers.js v6 · 零构建依赖 · 中文/English 双语壳层 · 瑞士极简黑白设计系统
- **合约**：Solidity（Foundry 工作区）· Uniswap V2 风格 AMM · 自研 Staking 矿池
- **数据**：Multicall3 批量读取 · Factory 交易对 1h 缓存 · OKB 价格（CoinGecko）· 5 路 RPC 故障转移（`rpc.xlayer.tech` 官方主节点 + OKX / drpc / Ankr / BlastAPI）
- **部署**：GitHub Pages（Namecheap CNAME → `xpower.world`）· 每次发布 `deploy.sh` 同步 `index.html`

## 📦 发布流程

```bash
cp "XPower Swap DApp.html" index.html
git add -A && git commit -m "..." && git push
# GitHub Pages CDN 缓存 1–2 分钟，之后访问 https://xpower.world 即为新版
```

## 📊 xStock 资产

平台收录 OKX 官方 xStock 全套 **63 个** wrapped 股票资产（`wAAPLx`、`wTSLAx`、`wNVDAx`、`wMETAx`、`wCOINx`…），Logo 取自官方 token 列表 CDN，代码见前端 `OFFICIAL_XSTOCK` 表。

## 🛡 安全说明

- 本项目为 DeFi 实验性产品，合约未经第三方审计，请仅投入可承受损失的资金。
- 无常损失（Impermanent Loss）风险存在于所有 LP 池。
- 前端为开源只读代码，私钥永不离开钱包（浏览器签名）。
