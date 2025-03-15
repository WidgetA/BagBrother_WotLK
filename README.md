# BagBrother_WotLK

# 修改原因
国服怀旧服目前插件接口的版本和海外插件接口版本不一致，导致海外 WLK 可用的插件无法在国服使用，或者有各种报错。

## Change Log
### 2025/3/15
- 在 `core\classes\tab.lua`中，使用了较新的 `ItemButton` 创建 Frame，检测为中国大陆服务器时，替换为旧版的 `Button`。
- 更新至 11.1.7 版本