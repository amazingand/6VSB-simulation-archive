# 分析文件版本

分析文件采用 `<system>_<content>_vNN` 命名：

- v01：来自历史整合包的早期分析产物；
- v02：来自正式生产目录的当前分析产物。

图片只作为版本化产物保存；本次迁移仅比较路径、大小和 SHA-256，没有读取图片内容。v02 文件与 `simulations/.../smd_production/` 原路径的对应关系记录在 `PROVENANCE_MAP.tsv`。
