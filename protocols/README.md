# 当前规范部署文件

`protocols/construct-X/{cleaved,uncleaved}/` 是当前部署文件的规范入口。

- 文件名保持稳定；
- 版本变化记录在 `ITERATION_HISTORY.md` 和 `archive/`；
- 与 `simulations/.../amber/` 的部署副本通过根目录 `PROVENANCE_MAP.tsv` 校验；
- 修改输入、脚本或 RST 后，必须建立新历史快照，不能回写旧快照。

