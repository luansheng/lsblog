# Quarto 发布 SOP

适用仓库：`lsblog`

## 背景

当前 [posts/_metadata.yml](posts/_metadata.yml) 设置了 `freeze: true`。

这意味着：

- `quarto publish gh-pages` 可能直接复用已有冻结结果；
- 只改了代码块、图、随机抽样结果或执行输出时，**源文件已变，但发布页可能还是旧内容**；
- 最常见的症状就是：本地 `.qmd` 看起来已更新，但线上页面仍停留在几小时前的旧版本。

因此，发布前要先判断这次修改属于哪一类。

---

## 一、标准判断

### A. 只改正文，不改代码执行结果
例如：

- 改文字
- 改标题
- 改表述
- 改不依赖代码执行的说明段落

这类修改通常可以直接发布：

```bash
printf 'Y\n' | quarto publish gh-pages
```

### B. 改了代码、图、随机抽样、表格输出
例如：

- 改 R 代码块
- 改 `sample()`、`set.seed()`
- 改图参数
- 改 `visped()`、`ggplot()` 输出
- 改统计结果或数据路径
- 改任何会影响 `_freeze` / `_site` 输出的内容

这类修改必须先刷新冻结结果，再发布：

```bash
quarto render posts/your-post/index.qmd --cache-refresh
printf 'Y\n' | quarto publish gh-pages
```

### C. 同时改了多篇带执行结果的文章
这类情况直接全站刷新后再发布：

```bash
quarto render --cache-refresh
printf 'Y\n' | quarto publish gh-pages
```

---

## 二、固定发布流程

建议以后固定使用下面的 5 步。

### 1. 确认当前在源码分支
推荐在 `main` 上编辑和发布，不要把 `gh-pages` 当作主写作分支。

```bash
git branch --show-current
```

### 2. 判断是否涉及冻结输出
只要修改包含以下任一项，都按“需要刷新 freeze”处理：

- 代码块
- 图形
- 随机抽样
- 表格结果
- 计算输出
- 依赖数据

### 3. 先 render，再 publish
- 单篇变动：刷新单篇
- 多篇变动：刷新全站

### 4. 发布到 `gh-pages`

```bash
printf 'Y\n' | quarto publish gh-pages
```

### 5. 发布后做一次核对
至少检查三件事：

- 本地生成页 `_site/.../index.html` 是否已更新
- 冻结结果 `_freeze/.../html.json` 是否已更新
- 发布分支 `gh-pages` 上对应 HTML 是否已包含新文字

---

## 三、推荐的日常用法

### 情形 1：只改文字

```bash
printf 'Y\n' | quarto publish gh-pages
```

### 情形 2：只改一篇带代码的文章

```bash
quarto render posts/million_ped-20260324/index.qmd --cache-refresh
printf 'Y\n' | quarto publish gh-pages
```

### 情形 3：改了多篇文章或不确定哪些输出受影响

```bash
quarto render --cache-refresh
printf 'Y\n' | quarto publish gh-pages
```

---

## 四、出问题时先检查什么

如果线上页面没有更新，按这个顺序排查：

1. **先看源文件是否真的改了**
2. **再看 `_freeze` 是否还是旧结果**
3. **再看 `_site` 是否仍是旧 HTML**
4. **再看 `gh-pages` 分支上的 HTML 是否更新**
5. **最后再怀疑 GitHub Pages 缓存**

经验上，大多数问题都不是 `publish` 失败，而是 **`freeze: true` 复用了旧执行结果**。

---

## 五、一个最稳妥的原则

> 只要这次修改会影响代码执行结果，就不要直接 `quarto publish gh-pages`，而要先 `quarto render ... --cache-refresh`。

这是这个仓库最重要的发布规则。
