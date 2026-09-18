# mbcrdt 项目申报书

- **项目名称**：mbcrdt
- **GitHub 仓库**：https://github.com/logicore-code/mbcrdt
- **项目许可证**：Apache-2.0

## 项目方向（通用性说明）

mbcrdt 是面向 MoonBit 生态的 **Conflict-free Replicated Data Type** 基础设施层。CRDT 是一种"多副本无需协调就能最终收敛到同一份状态"的数据结构，本身不绑定具体业务——凡是需要在不可靠网络上维护共享可变状态的 MoonBit 程序都能直接复用这套库，比如离线优先应用、协同编辑、AI Agent 集群状态共享、边缘计算数据汇聚等。MoonBit 生态目前还没有功能重合的成熟 CRDT 实现，本项目想把这块拼图补齐。

## 项目简介

用纯 MoonBit 实现了一组工业级 CRDT，覆盖计数器（GCounter / PNCounter）、集合（GSet / TwoPSet / ORSet）、键值（LWWRegister / LWWMap）和协同序列（RGA）四类共 8 个类型，外加 Dot / CausalContext 两个版本向量原语。每个 CRDT 的 `merge` 都满足 commutative / associative / idempotent 三大代数律，这一性质已经用 property-based tests 钉死；目前 70+ 测试用例全绿，CI 会自动跑 `moon check` / `fmt --check` / `test` 和三个 demo 的烟雾测试。同一份代码同时编译到 wasm / wasm-gc / js / native 四个后端，零外部依赖。

## 预期使用场景

1. **离线优先的协同笔记 / 文档**。用户在本地编辑、多端同步，不需要中心化服务器；离线期间的修改在恢复连接后自动合并，不会丢也不会重。仓库里 `examples/collaborative_text` 已经能用 RGA 复现 Figma / Notion 这类产品的合并语义。

2. **AI Agent 集群的共享状态**。multi-agent workflow engine 里的投票集合、在线成员表、任务计数都是常见需求。`ORSet` 的"并发 add 胜出 remove"语义正好对应"投票去重 + 离线回放"这类业务——Agent 离线时提交的请求回到集群后既不会重复也不会丢失。

3. **边缘计算 / IoT 数据汇聚**。边缘节点间歇性联网、先攒本地数据是常态。`GSet` / `PNCounter` 体积小、合并代价低、保证最终一致，对弱网或断网场景非常友好。

## 拟实现的核心功能

- 8 种 CRDT：`GCounter`、`PNCounter`、`GSet`、`TwoPSet`、`ORSet`、`LWWRegister`、`LWWMap`、`RGA`
- 配套原语 `Dot`（事件 ID）与 `CausalContext`（版本向量）
- 每个 CRDT 的 `merge` 都满足交换律 / 结合律 / 幂等律，已用 property tests 验证
- 70+ 单元 / 属性测试；3 个 `moon run` 可执行 demo（counter / 协同文本 / tag cloud）
- CI 工作流（GitHub Actions）跑 fmt / check / info / test + 三 demo 烟雾测试
- 顶层 `mbcrdt.mbt` 暴露 `actor()` / `new_gcounter()` 等便捷构造函数
- 零外部依赖，兼容 wasm / wasm-gc / js / native 四个 MoonBit 后端

## 原创 / 移植 / 参考说明

**原创项目**。算法基于以下公开学术成果（每个源文件头部已注明引用）：
- Shapiro, M., Preguiça, N., Baquero, C., Zawirski, M. (2011). *A comprehensive study of Convergent and Commutative Replicated Data Types.* INRIA TR 7506.
- Baquero, C., Almeida, P., Cunha, A. (2024). *The Algebra of CRDTs.*
- Letia, M., Preguiça, N., Shapiro, M. (2009). *Consistency without ordering: The CRDT whiteboard case study.*
- Bieniusa, A. et al. (2012). *An optimized conflict-free replicated set.*
- Almeida, P., Shoker, A., Baquero, C. (2018). *Delta State Replicated Data Types.*

MoonBit 代码完全独立编写，**非移植项目**，MoonBit 生态目前也尚无功能重合的成熟 CRDT 库可供参照。