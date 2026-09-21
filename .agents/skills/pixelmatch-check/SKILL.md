---
name: pixelmatch-check
description: |
  Figma 设计还原度视觉对比检查与自动修复。触发条件：
  - 提示词包含 "pixelmatch"、"对比"、"还原度"、"视觉检查"、"pixel perfect"、"设计对比" 等关键词
  - 用户要求检查页面与 Figma 设计稿的一致性
  示例触发："检查一下这个页面和设计稿的还原度 https://figma.com/design/xxx?node-id=123-456"
---

# Figma 设计还原度视觉对比检查

通过 `npx pixelmatch` 像素级对比，检测页面实现与 Figma 设计稿之间的视觉差异，并驱动 AI 迭代修复（Web 端）或告知用户手动修复（非 Web 端）。

## 第 0 步：平台确认

停下来询问用户：

选项：
- **Web 端（默认）**：使用 `/playwright-cli` 技能自动截图，支持视口自适应和自动修复循环
- **非 Web 端（本地图片）**：提供本地截图路径，执行对比后告知 diff 图位置，由用户手动修复

## 第 1 步：环境检测

完成以下检测。任一失败则停止技能执行并提示用户。

检测项：

1. **Node.js >= 18**：运行 `node --version`
   - 失败提示：`需要 Node.js >= 18。请安装：https://nodejs.org/`

2. **npx 可用**：运行 `npx --version`
   - 失败提示：`npx 不可用，请确认 npm 已正确安装`

3. **Figma MCP 可用**：第 3 步调用 Figma MCP 获取截图；调用失败则提示用户检查 Figma MCP 连接和 Figma 文件权限。

4. **`/playwright-cli` 可用（仅 Web 端）**：加载 `/playwright-cli` 技能，运行 `playwright-cli --version`。
   - 失败提示：`playwright-cli 不可用，请先确认 /playwright-cli 技能和本地 CLI 已安装`

## 第 2 步：创建存储目录

在项目根目录下创建本次运行的存储目录（所有产物均存放于此）：

```bash
mkdir -p pixelmatch-checks/YYYY-MM-DD-<页面>
```

- 日期：当前日期（格式 YYYY-MM-DD）
- 节点名：从 Figma URL 的 node-id 提取，sanitize 为合法目录名（特殊字符替换为 `-`，转小写）
- 示例：`pixelmatch-checks/2026-03-17-product-page/`

确认 `pixelmatch-checks/` 已加入项目根目录的 `.gitignore`（若未存在则追加）。

后续所有文件均保存到此目录（简写为 `<OUT_DIR>/`）。

## 第 3 步：获取 Figma 基准截图 + 设计稿尺寸

1. 从用户提供的 Figma URL 中提取 `fileKey` 和 `nodeId`：
   - URL 格式：`https://figma.com/design/:fileKey/:fileName?node-id=:int1-:int2`
   - nodeId 中 `-` 转为 `:`（如 `123-456` → `123:456`）

2. 调用 Figma MCP `mcp__figma__get_screenshot`：
   - 参数：`fileKey=<fileKey>`、`nodeId=<nodeId>`、`maxDimension=65536`
   - 默认使用返回的截图 URL 和 curl 指令，保存到 `<OUT_DIR>/figma-baseline.png`
   - 仅在无法通过 URL 下载时使用 `enableBase64Response: true` 并将 base64 解码到 `<OUT_DIR>/figma-baseline.png`

3. 从 Figma MCP 响应记录设计稿尺寸：
   - 优先使用 `original_width` / `original_height`
   - 缺失时使用 `width` / `height`
   - 保存为 `<OUT_DIR>/figma-size.json`，格式：`{"width":1440,"height":900,"isMobile":false}`

4. 判断设计稿是否为手机尺寸：
   - `width <= 480 && height > width`：判定为手机尺寸
   - 手机尺寸时，Web 端使用移动视口和移动 UA；截图优先使用 `--full-page`，再按基准图尺寸裁剪或补齐到同尺寸后执行 pixelmatch
   - 桌面尺寸时，Web 端使用设计稿原始宽高作为视口

5. 将 Figma URL 保存到 `<OUT_DIR>/figma-url.txt`。

## 第 4 步：获取实际截图

### Web 端

1. 停下来询问用户预览地址：
   - "请提供页面的本地预览地址（如 http://localhost:5173/products）"

2. 停下来询问用户选择动态内容排除策略：

   **选项 1：AI 智能识别 + 代码分析自动遮罩（推荐）**
   - 扫描组件代码找到动态数据绑定（v-for、`{{ item.xxx }}`、`:src` 等），生成 Playwright mask 选择器遮罩动态区域
   - 对比后 AI 再分析剩余 diff，过滤漏网的动态内容差异
   - 优点：最全面，双保险机制
   - 缺点：两步处理，稍慢

   **选项 2：Mock 数据方案（最精确）**
   - 临时修改组件源码，将动态数据替换为与 Figma 设计稿一致的固定文本/图片
   - 完成对比后仅恢复本轮临时改动；若目标文件存在非本轮改动，停止并提示用户确认
   - 优点：最精确，对比结果最干净
   - 缺点：有临时代码修改（需严格追踪改动边界）

3. 若选择选项 1（代码分析遮罩）：
   - 读取当前实现的组件源代码（Vue/React/HTML 模板）
   - 识别动态绑定：`v-for`、`:src`、`{{ variable }}`、`v-if/v-show` 等
   - 生成 CSS 选择器列表作为 mask

4. 加载并遵循 `/playwright-cli` 技能，先建立插件模式会话：
   ```bash
   playwright-cli open --extension
   ```

5. 设置视口：
   ```bash
   playwright-cli resize <width> <height>
   ```
   - 桌面尺寸：`width` 和 `height` 使用第 3 步获取的设计稿尺寸
   - 手机尺寸：`width` 使用设计稿宽度，`height` 使用 `min(设计稿高度, 932)`；在 `goto` 前通过 `run-code` 设置移动 UA 和移动端特征：
     ```javascript
     async page => {
       const userAgent = 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1'

       await page.setExtraHTTPHeaders({ 'user-agent': userAgent })
       await page.addInitScript(ua => {
         Object.defineProperty(navigator, 'userAgent', { get: () => ua })
         Object.defineProperty(navigator, 'platform', { get: () => 'iPhone' })
         Object.defineProperty(navigator, 'maxTouchPoints', { get: () => 5 })
       }, userAgent)
     }
     ```

6. 进入目标页面：
   ```bash
   playwright-cli goto <预览地址>
   ```

7. 使用 `playwright-cli run-code` 注入脚本（禁用动画 + 应用遮罩）：

   ```javascript
   async page => {
     await page.addStyleTag({
       content: `
         *, *::before, *::after {
           animation: none !important;
           transition: none !important;
           caret-color: transparent !important;
         }
       `
     })

     for (const selector of ['/* 动态选择器 */']) {
       await page.locator(selector).evaluateAll(elements => {
         elements.forEach(el => { el.style.visibility = 'hidden' })
       })
     }
   }
   ```

8. 截图保存为 `<OUT_DIR>/actual-screenshot.png`：
   ```bash
   playwright-cli screenshot --filename=<OUT_DIR>/actual-screenshot.png
   ```
   手机尺寸或长页面设计稿使用：
   ```bash
   playwright-cli screenshot --full-page --filename=<OUT_DIR>/actual-screenshot.png
   ```


## 第 5 步：Pixelmatch 对比

```bash
npx pixelmatch \
  <OUT_DIR>/figma-baseline.png \
  <OUT_DIR>/actual-screenshot.png \
  <OUT_DIR>/diff-output.png \
  0.1
```

- stdout 输出 diff 像素数（整数）
- 根据设计稿尺寸计算差异百分比：`diffPercent = diffPixels / (width × height) × 100`
- 状态判断：
  - < 2%：PASS ✅，无需修复
  - 2%–5%：WARN ⚠️，建议修复
  - 5%–10%：FAIL ❌，需要多轮迭代
  - >= 10%：CRITICAL 🚨，建议检查基准图是否正确

## 第 6 步：差异处理

### Web 端（自动修复循环）

差异 > 2% 时启动修复循环，最多 5 轮：

1. 使用 Read 工具读取 `<OUT_DIR>/diff-output.png`，查看红色高亮区域，定位差异位置
2. 使用 `/playwright-cli` 的 `run-code` 测量关键元素：
   - `getComputedStyle(el)` 获取 fontSize、padding、margin、color 等
   - `el.getBoundingClientRect()` 获取位置和尺寸
3. 将测量值与 Figma 设计规格逐属性对比
4. 仅修复样式/布局偏差（**绝不修改数据绑定逻辑**）
5. 重新截图并执行第 5 步对比

退出条件（满足任一即停止）：
- 差异百分比 < 5%
- 已迭代 5 轮
- 连续两轮差异改进 < 1%（收敛）

### 非 Web 端（告知用户手动修复）

输出以下信息后结束技能执行：

```
对比完成。

差异像素数：X 像素，差异百分比：X.XX%（状态：PASS/WARN/FAIL/CRITICAL）

产物目录：<OUT_DIR>/
  - figma-baseline.png：Figma 基准截图
  - actual-screenshot.png：实际截图
  - diff-output.png：差异图（红色区域为差异点）

请打开 diff-output.png 查看红色标注区域，与 figma-baseline.png 对比后手动修复。
```

## 第 7 步：生成还原度报告（Web 端）

保存到 `<OUT_DIR>/report.md`：

```markdown
## 设计还原度检查报告

- Figma 设计稿：[Figma URL]
- 平台：Web 端
- 动态排除策略：[所选策略名称]
- 最终差异百分比：X.XX%
- 状态：[PASS ✅ / WARN ⚠️ / FAIL ❌ / CRITICAL 🚨]
- 迭代修复次数：N 轮
- 产物目录：<OUT_DIR>/

### 已修复的差异
- [CSS 属性]: 修复前值 → 修复后值

### 剩余差异说明
- [说明为何忽略，如"商品图片为动态内容"]
```
