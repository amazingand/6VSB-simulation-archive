# Cprime 仓库重构状态

更新时间：2026-08-17（Asia/Shanghai）

## 当前阶段

- 工作流节点：V1 独立验证已通过，W3 发布准备中。
- 正式重构分支：`codex/restructure-cprime-history-2026-08-17`。
- 基线：`bd4fa7de20cca296c388f132c1bb358e9ce2e18f`，即 PR #6 合并后的 `main`。
- 隔离工作树：`D:\database\6VSB-worktrees\restructure-cprime-history-2026-08-17`。
- 原工作目录中的 6 个未提交修改保持不变，并已在忽略的 `work/pre_restructure_guard_20260817/` 建立副本、补丁和 SHA-256 保护点。

## 当前约束

- 项目代号统一写作 `Cprime`。
- 当前只处理文件组织、版本、校验、Git/GitHub 和来源映射，不分析研究内容。
- `analysis` 下图片只比较路径、大小和 SHA-256，不读取图像内容。
- 正式仓库目录和 Git 状态只能由主代理串行写入。
- 子代理可以并行只读；临时审计区同一时刻只允许一个写入代理。
- 本阶段只清理仓库当前树；不重写既往 Git、标签或 Git LFS 历史。
- 历史压缩包在完成成员审计和用户确认前不得删除或上传。

## 下一道 Gate

1. 重新生成仓库级 `SHA256SUMS`，并用 Windows PowerShell 5.1 执行校验。
2. 以明确 pathspec 暂存并复核 cached diff。
3. 提交后从干净检出目录复核重构结果。
4. 通过后推送并创建 draft PR；未经用户后续指令不合并。
