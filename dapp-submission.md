# XPower Swap · DApp 收录提交材料包

> 用途：向各大 DApp/代币目录提交 XPower Swap。复制对应小节内容粘贴到各平台表单即可。
> 项目信息核对日期：2026-10-12

---

## 一、项目基础信息（通用字段）

| 字段 | 值 |
|---|---|
| 项目名称 | XPower Swap |
| 符号 | XPR |
| 一句话介绍 | XLayer 上的 xStock 股票资产 DEX：OKB × 63 个 wrapped 股票代币兑换、流动性、质押 Farm 与一键发盘 |
| 官网 | https://xpower.world |
| 源码 | https://github.com/yaetcc/xpower-swap |
| 链 / 网络 | X Layer（EVM · chainId 196） |
| 分类 | DEX / AMM / 发射台（Launchpad）/ Yield Farming |
| 支持钱包 | OKX Wallet、MetaMask 等任何 WalletConnect/EIP-1193 钱包 |
| 团队/开发者 | yaetcc（独立开发者） |
| 合约已验证 | 是（区块浏览器源码验证） |

## 二、核心合约（X Layer）

- Factory（交易对工厂）：`0xfdBA35dbB9a7a2c01dA3aafD6E6900e9e1838805`
- Router（路由）：`0xA6086c26C449f58047DD94487c94796D684cB442`
- Staking（矿池）：`0x9C2e0c1ca789B6582cD05BefE1f695b8E55cb955`
- XPR（平台奖励币）：`0xcd76b6223b045fc97b04ef0Ef427a0a5a0561BCF`
- XPRS（分红币）：`0xcfc2e529309dCf29a9BBEa90D6fd33Fc365DEEeE`

## 三、英文描述（目录类平台用）

> XPower Swap is a decentralized exchange on X Layer (chainId 196) focused on xStock — wrapped US stock tokens issued by OKX. Trade OKB against 63 stock assets (AAPL, TSLA, NVDA, META, COIN...), provide liquidity, farm rewards with one-click pool creation, and launch your own token with a built-in Factory/Router/Staking stack. Fully open-source, single-file frontend with 5-node RPC failover and Multicall3 batched reads.

## 四、平台逐个提交指引

### 1. OKX Wallet 探索 / 收录（已开过申请页）
- 入口：https://web3.okx.com/zh-hans/drops/apply （OKX 生态项目申请）
- 提交内容：项目名称 XPower Swap、官网、合约地址（上表）、链 X Layer、简介（第三节）
- 说明：OKX 钱包探索页收录一般要求项目部署在 OKX 生态链（X Layer 满足）

### 2. DappRadar
- 入口：https://dappradar.com/dapp-listing 或官网 Submit DApp
- 需注册账号；类别选 **DeFi → DEXes / Yield**；链选 **X Layer**（若无此链选项选 "Other EVM" 并在描述注明 chainId 196）

### 3. Coinranking（币种收录，已开过）
- 入口：https://coinranking.com/coin-listing/list-coin
- 提交内容：代币 **XPR** + 合约 `0xcd76b6223b045fc97b04ef0Ef427a0a5a0561BCF` + 官网 + 图标（仓库 `assets/logos/XPR.png`）
- 注意：XPR 是平台奖励币；若平台要求额外信息（团队邮箱、社交），建议提供 Twitter/X 或 Telegram 后补

### 4. DeFiLlama（TVL 收录，可选）
- 入口：https://defillama.com/submit-a-project
- 需提供 TVL 合约地址（Factory）、链信息、API/脚本；README 已含合约表
- 说明：DeFiLlama 收录流程较工程化，若短期不上 TVL 可延后

### 5. CoinGecko（已由用户决定跳过）
- 需 Google 登录 + 代币持有者签名验证，当前跳过

## 五、素材清单

- Logo（币标）：仓库 `assets/logos/`（XPR.png、XPRS.png）
- 官网截图：`_shots/` 目录（本地自检截图，可上传）
- 社交：建议注册 Twitter/X 与 Telegram 群（各平台表单常见必填项）

## 六、注意事项

- 各平台审核周期通常 3–30 天，被拒可补充信息后重新提交
- 提交时「合约已验证」勾选可显著提高通过率（源码已在区块浏览器 Verify）
- 若平台要求提供合约源码文件，见 `contracts/`（Foundry 工程，含 XStorkFactory / XStorkRouter / XStorkStaking / XPowerToken）
