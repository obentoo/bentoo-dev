# bentoo-dev

[English](README.md) · [Português (Brasil)](README.pt-BR.md) · [Español](README.es.md) · [Русский](README.ru.md) · **简体中文**

> 本文译自英文版 [`README.md`](README.md)，以英文版为准：两者不一致时，请以英文版为准。

一款用于开发和维护 **Gentoo ebuild 与 overlay** 的 Claude Code 插件。为 ebuild 的完整生命周期（创建、编辑、版本升级、清理、QA 验证）提供专用技能（skill）、子代理、钩子（hook）、监视器和参考资料。

> **状态：** v0.4.0 — README 与权限提示已翻译为西班牙语、巴西葡萄牙语、俄语和简体中文（见 `CHANGELOG.md`）。
> **规范目标：** Claude Code v2.1.259+（后续版本同样适用）。

> **与具体 overlay 无关。** 本插件虽由 Bentoo 项目维护，但面向**任何**活跃的
> Gentoo overlay。各项约定取自检测到的 overlay 的 `metadata/layout.conf`
> （`masters`、`thin-manifests`、`manifest-hashes`），而非其名称。提及 bentoo
> overlay 的示例仅作说明之用。

### Claude Code 最低版本

| 插件使用的功能                                              | 最低版本        |
|-------------------------------------------------------------|:---------------:|
| `--bare` 参数（与 `/bentoo-dev:*` 命令不兼容）              | v2.1.81         |
| `SessionStart` / `CwdChanged` 钩子                          | v2.1.83         |
| `PreToolUse` `permissionDecision: "ask"` JSON 结构          | v2.1.83         |
| `permissionDecision: "defer"`（仅限无头模式 `-p`）          | v2.1.89         |
| `bin/` 自动加入 PATH                                        | v2.1.91         |
| `hookSpecificOutput.sessionTitle`（UserPromptSubmit）       | v2.1.94         |
| `monitors/monitors.json` 后台监视器                         | v2.1.105        |
| `claude plugin tag`（发布版本）                             | v2.1.118        |
| exec 形式的钩子（`"args": []`）                             | v2.1.139        |
| `displayName` 清单字段                                      | v2.1.143        |
| 来自 `Stop`/`SubagentStop` 的 `additionalContext`           | v2.1.163        |
| `if:` 条件正确限定于所匹配的命令                            | v2.1.259        |
| 总体规范目标                                                 | **v2.1.259+**   |

上表每一行都已对照
[上游 CHANGELOG](https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md)
核实，只有三项例外：它们没有对应的 changelog 条目，未经核实沿用至今：
`bin/` 自动加入 PATH（v2.1.91）、`displayName`（v2.1.143），以及
`permissionDecision: "ask"` 的引入（v2.1.83 — v2.1.101 的后续条目提到它时称其
已经存在，因此该功能确实存在，只是引入它的版本尚未确认）。`statusMessage`
同样没有 changelog 条目，因此不标注任何版本，而不是填一个猜测的版本。

总体目标取最高的条目，而不是更低的版本：插件用到了表中列出的每一项功能。其中 v2.1.259
修复了 *“钩子的 `if` 条件（如 `Bash(cat *)`）在无关的 Bash 命令上触发”* — 本插件
通过 `if: Bash(cp *)` / `(mv *)` / `(sed *)` 路由六个钩子，因此在更早的版本上，它们会
在无关命令上触发。脚本在找不到 `.ebuild` 时以 0 退出，所以两种情况下行为都正确；
区别只在于白白启动的进程。

---

## 功能

- **单一的自然语言入口** — `/bentoo-dev:bentoo "<instruction>"`。
  该技能接收自由格式的请求，识别意图
  （`create` / `bump` / `edit` / `qa` / `clean` / `bootstrap`），有歧义时询问用户，
  加载对应的参考资料（`skills/bentoo/references/<intent>.md`），
  并将任务委派给负责该操作的专用子代理。示例：
  - `/bentoo-dev:bentoo "create dev-libs/foo 1.2.3 from <upstream>"` → `ebuild-creator`
  - `/bentoo-dev:bentoo "bump app-misc/bar to 2.1"` → `ebuild-bumper`
  - `/bentoo-dev:bentoo "add USE flag wayland to games-util/baz"` → `ebuild-editor`
  - `/bentoo-dev:bentoo "run QA on dev-libs/foo"` → `qa-checker`
  - `/bentoo-dev:bentoo "clean the whole overlay"` → `overlay-maintainer`
  - `/bentoo-dev:bentoo "bootstrap a new overlay at ~/myoverlay"` → `overlay-maintainer`

  基于描述匹配的自动触发依然有效 — *“bump mesa to 26.0.5”*
  或 *“package XYZ from .deb”* 无需输入 `/bentoo-dev:bentoo` 即可自动调用该技能。
- **5 个专用子代理**，位于 `agents/` — 由 `bentoo` 技能通过 `Agent` 工具调用；每个子代理都声明 `effort`、`maxTurns`、`tools`、`disallowedTools`、`color`，并通过 `skills:` frontmatter 预加载 gotchas 参考资料。
- **确定性钩子**，覆盖 11 个生命周期事件 — 完整列表见 [Hooks](#hooks)。其中起关键作用的有：
  - `SessionStart` / `CwdChanged`（自动检测 overlay，并缓存为有界摘要）。
  - `PreToolUse` Bash（rm 安全检查，给出 `deny`/`ask` 决定）。
  - `PostToolUse` Write|Edit（lint、Manifest 提醒）。
  - `PostToolUse` Bash `if: cp|mv|sed`（捕获绕过 Write|Edit、经由 Bash 对 `.ebuild` 的修改；有意不使用 `FileChanged` — 它匹配的是字面文件名，而不是通配模式）。
  - `Stop`（Manifest 过期检查关卡，识别 `thin-manifests`）。
  - `PreCompact`（重新注入 overlay 身份信息，使其在压缩后得以保留）和
    `StopFailure`（将因 API 错误而终止的情况记录到 `${CLAUDE_PLUGIN_DATA}/stop-failures.log`）。
- **后台监视器**（v2.1.105），监视 portage ELOG 和 `pkgcheck` 的检查结果，仅在相关技能调用期间运行。
- **输出样式** `qa-report`，用于生成确定、可解析的 QA 报告。
- **本地化的权限提示** — rm 安全钩子的 `ask` 提示跟随你的语言环境（`LANGUAGE`、`LC_ALL`、`LC_MESSAGES`、`LANG`，与 gettext 相同），支持西班牙语、巴西葡萄牙语、俄语和简体中文，否则回退到英语。Claude 读取的一切内容 — 技能、代理、参考资料、钩子上下文、`deny` 和 `block` 原因 — 都有意保持英文：翻译后的提示会让模型表现变差，也帮不了任何用户。见 `scripts/lib/i18n.sh`。
- **英文触发词**，集中在 `bentoo` 技能的 `description` 和 `when_to_use` 中，使全部六种操作都能高保真地自动触发。自 0.3.0 起，用其他语言书写的指令不再自动触发该技能；请用 `/bentoo-dev:bentoo "…"` 显式调用。
- **15 个 ebuild 模板**，位于 `assets/templates/`（包括 `source-pypi`、`virtual`、`acct-user`、`acct-group`），外加 `metadata.xml` 和一个 GLEP 42 `news-item.txt`；通过 `render-template.sh --env` 进行规范的占位符替换，支持参数化的 `@@EAPI@@`（默认渲染为 8；可选 `EAPI=9`）和 `@@KEYWORDS@@`。
- **按 overlay 区分的配置档**，位于 `assets/profiles/` — 目前有 `bentoo` 和 `default`。
- **模块化参考资料**，位于 `references/` — `gotchas.md` 作为技能预加载；其余按需延迟加载。

---

## 安装

### 本地（开发 / 个人使用）

将仓库克隆到工作目录，并通过 `--plugin-dir` 加载插件：

```bash
git clone <this-repo> ~/.claude/plugins/bentoo-dev
claude --plugin-dir ~/.claude/plugins/bentoo-dev
```

### Marketplace

发布后，可通过以下方式安装：

```bash
/plugin install bentoo-dev@<marketplace-name>
```

### 配置用户值

通过 `userConfig`（Claude Code 会在安装时提示）或编辑插件配置，一次性设置你的 Gentoo 身份：

| 键                        | 用途                                                 | 默认值                   |
|---------------------------|------------------------------------------------------|--------------------------|
| `maintainer_email`        | `metadata.xml` 中的 `<email>`                        | `lucascs@protonmail.com` |
| `maintainer_name`         | `metadata.xml` 中的 `<name>`                         | `lucascouts`             |
| `maintainer_type`         | `type=` 属性（`person` / `project` / `nobody`）      | `person`                 |
| `default_keywords`        | 新 ebuild 的 KEYWORDS                                | `~amd64`                 |
| `preferred_overlay_path`  | 可选的默认 overlay 路径（为空时自动检测）            | _（未设置）_             |

这些值以 `CLAUDE_PLUGIN_OPTION_*` 环境变量的形式提供给脚本和子代理（该前缀符合 Claude Code v2.1.x `env-vars` 参考文档的现行规范）。

---

## 目录结构

```
bentoo-dev/
├── .claude-plugin/plugin.json      # manifest (semver, userConfig)
├── README.md
├── CHANGELOG.md
├── LICENSE
├── skills/                         # 1 user-invocable + 1 internal preload
│   ├── bentoo/
│   │   ├── SKILL.md                # natural-language router
│   │   └── references/             # progressive-disclosure detail per intent
│   │       ├── create.md
│   │       ├── bump.md
│   │       ├── edit.md
│   │       ├── qa.md
│   │       └── clean.md
│   └── gotchas/SKILL.md            # internal: preloaded by sub-agents
├── agents/                         # 5 sub-agents (delegated via Agent tool)
│   ├── ebuild-creator.md
│   ├── ebuild-editor.md
│   ├── ebuild-bumper.md
│   ├── overlay-maintainer.md
│   └── qa-checker.md
├── hooks/hooks.json                # SessionStart / CwdChanged / PreToolUse / PostToolUse / SubagentStop / Stop / PreCompact
├── monitors/monitors.json          # portage-elog + pkgcheck-watch (v2.1.105+)
├── output-styles/qa-report.md      # deterministic QA report format
├── scripts/                        # shell helpers used by hooks / agents / monitors
│   ├── detect-overlay.sh           # --summary (default) | --full
│   ├── overlay-context.sh          # cache-first context for the skill
│   ├── lib/hook-common.sh          # shared payload/target helpers
│   ├── lib/i18n.sh                 # message catalogs for user-facing hook text
│   ├── cache-overlay.sh            # SessionStart / CwdChanged hook target
│   ├── quick-lint.sh
│   ├── manifest-reminder.sh
│   ├── manifest-stale-check.sh
│   ├── safety-rm-check.sh
│   ├── monitor-elog.sh
│   ├── monitor-pkgcheck.sh
│   ├── render-template.sh          # substitutes @@VAR@@ in templates
│   └── plugin-data-dir.sh
├── tests/i18n.bats                 # catalogs, locale selection, localized rm prompt
├── bin/                            # PATH-exposed wrappers
│   ├── gentoo-overlay-detect
│   ├── gentoo-overlay-cache
│   └── gentoo-ebuild-lint
├── references/                     # progressive-disclosure docs
│   ├── gotchas.md                  # preloaded via skills/gotchas
│   ├── eclass-guide.md
│   ├── dependency-syntax.md
│   └── language-ecosystems.md
├── assets/
│   ├── profiles/  (bentoo.md, default.md)
│   └── templates/  (15 *.ebuild + metadata.xml + news-item.txt)
└── evals/  (evals.json, trigger-queries.json)
```

---

## Hooks

| 事件               | Matcher / 过滤器                              | 脚本                                  | 用途                                                                                          |
|--------------------|-----------------------------------------------|---------------------------------------|-----------------------------------------------------------------------------------------------|
| SessionStart       | _（无）_                                      | `cache-overlay.sh`                    | 检测一次活跃的 overlay，并将摘要和字段缓存为 `${CLAUDE_PLUGIN_DATA}/overlay.json`。          |
| SessionEnd         | _（无）_                                      | `cleanup-cache.sh`                    | 丢弃本会话的 overlay 缓存，使下一个会话从头重新检测。                                         |
| CwdChanged         | _（无）_                                      | `cache-overlay.sh`                    | 用户在不同 overlay 之间切换时刷新缓存。                                                       |
| UserPromptSubmit   | _（无）_                                      | `session-title.sh`                    | 对 `/bentoo-dev:*` 调用，通过 `hookSpecificOutput.sessionTitle` 自动重命名会话。             |
| PreToolUse         | `Bash` + `if: Bash(rm *)`                     | `safety-rm-check.sh`                  | 对删除目录中唯一 `.ebuild` 的 rm 给出 `deny`；对有孤立 DIST 风险的 rm 给出 `ask`。           |
| PreToolUse         | `Bash` + `if: Bash(git rm *)`                 | `safety-rm-check.sh`                  | 对 `git rm` 执行同样的关卡（单独一条 — 文档未说明 `if:` 支持管道符 OR）。                    |
| PostToolUse        | `Write\|Edit`                                 | `quick-lint.sh` + `manifest-reminder.sh` | lint EAPI、版权头和年份、`eapply_user`（限定于 `src_prepare`）、KEYWORDS、SLOT、LICENSE；SRC_URI 变更时提醒。 |
| PostToolUseFailure | `Bash`                                        | `manifest-failure-diagnose.sh`        | 对 `ebuild ... manifest` 失败进行分类（网络/校验和/404/权限）并建议后续步骤。                |
| PostToolUse        | `Bash` + `if: cp\|mv\|sed`                     | `quick-lint.sh` + `manifest-reminder.sh` | 捕获经由 Bash（`cp`/`mv`/`sed`）、绕过 `Write\|Edit` 对 `.ebuild` 的修改。               |
| SubagentStop       | `ebuild-creator`                              | `ebuild-creator-validate.sh`          | 若任何新建的包缺少 `metadata.xml` 或 `Manifest`，则阻止停止。                                 |
| Stop               | _（任意）_                                    | `manifest-stale-check.sh`             | 若被修改的 ebuild 的 Manifest 已过期，则阻止本轮结束（跳过 `thin-manifests` overlay）。      |
| StopFailure        | _（任意）_                                    | `stopfailure-log.sh`                  | 将因 API 错误（速率限制、计费、最大 token 数）而终止的情况记录到 `stop-failures.log`。       |
| PreCompact         | _（任意）_                                    | `precompact-reinject-overlay.sh`      | 重新注入缓存的 overlay 身份信息，使其在对话压缩后得以保留。                                   |

所有脚本都从 stdin 读取规范的钩子 JSON 负载，在 stdout 上输出
`hookSpecificOutput` JSON 结构（`permissionDecision` / `additionalContext` /
`sessionTitle` / `{decision: "block", reason}`），并以 0 退出。只要钩子的
stdout 能被解析并通过校验，就由它决定结果，与退出码无关。

每个钩子都使用 **exec 形式**（`"args": []`）：Claude Code 不经 shell 直接启动脚本，
因此插件路径中含有空格时也不会出现引号错误。`${CLAUDE_PLUGIN_ROOT}` 在两种形式中
都会被替换，两者也都会把它导出到启动的进程中。每个钩子还声明了
`statusMessage`，因此加载指示器会显示正在运行的内容。

`Stop` 和 `SubagentStop` 钩子遵守 `stop_hook_active` 循环保护。
Claude Code 会在连续 **八次** 阻止之后强制越过 `Stop` 钩子；如果某次收敛确实需要
更多次，可通过 `CLAUDE_CODE_STOP_HOOK_BLOCK_CAP` 提高该上限。

### 上下文预算：overlay 摘要有意设为有界

`scripts/overlay-context.sh` 是 `bentoo` 技能在加载时注入的内容。它从
`cache-overlay.sh` 写入的会话缓存中提供**有界摘要**（约 1.3 KB），只有当缓存
不覆盖当前目录时才重新运行检测。

原样转储的 `metadata/layout.conf` + `profiles/package.mask` **不在**
该摘要中。在真实的 overlay 上，仅 `package.mask` 就约有 15 KB — 每次调用都会注入
约 4k 个 token，而只有 `clean` / `mask` 意图才会读取它。需要时请显式加载：

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/overlay-context.sh" --full   # layout.conf + package.mask
bash "${CLAUDE_PLUGIN_ROOT}/scripts/detect-overlay.sh" --summary  # same summary, no cache
```

### 无需模型的批量 lint

`scripts/quick-lint.sh` 同时也是一个 CLI。`qa-checker` 代理每次运行时调用它一次，
因此七项机械检查不消耗任何成本：

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/quick-lint.sh" --json <ebuild> [<ebuild> ...]
# -> {"results":[{"file","errors","warnings"}],"summary":{"files","errors","warnings","status"}}
```

严重级别遵循 PMS：缺少 `SLOT` 或 `LICENSE` 属于**错误**（EAPI 8 中 SLOT 没有
隐式默认值）；过时的版权年份属于**警告**。`virtual/*`、`acct-user/*` 和 `acct-group/*`
不安装任何文件，因此有意不要求 `LICENSE`。始终以 0 退出 — 检查结果就是输出。

### `permissionDecision`：`ask` 与 `defer`

PreToolUse 钩子 `safety-rm-check.sh` 在孤立 DIST 的情况下输出
`permissionDecision: "ask"`（交互式提示），在删除包目录中唯一的 `.ebuild` 时
输出 `"deny"`。`defer` 专用于无头模式（`-p` 参数，v2.1.89+），
**不是**交互式“请确认”提示的正确取值。

### 加固 `rm`（fail-open 钩子 + 权限规则）

`safety-rm-check.sh` 是一道**尽力而为的护栏，而不是安全边界**：
`if: "Bash(rm *)"` 过滤器是 fail-open 的，且脚本按空白字符切分词元，
因此引号、`$()` 和 `&&` 链都可能绕过它。若要硬性拦截，请在你的设置中
搭配一条权限 `deny`/`ask` 规则，例如：

```json
{ "permissions": { "ask": ["Bash(rm *.ebuild)", "Bash(rm -r *)"] } }
```

作为兜底，钩子仍会把 `.ebuild` 文件附近的递归/通配 `rm` 升级为
`ask` 提示。

### 检查点（checkpointing）注意事项

这里有两项限制叠加在一起，合起来意味着**本插件产出的任何内容都无法用 `/rewind` 恢复**：

1. 检查点**不会**跟踪 Bash 命令（`rm`、`mv`、`cp`、`sed`）修改的文件 — 只跟踪
   `Write`/`Edit`/`NotebookEdit`。通过 `ebuild … manifest` 重新生成的 `Manifest`，
   或用 `cp` 复制的 `.ebuild`，都不会被撤销。
2. 检查点**也不会恢复子代理的修改**。根据
   [检查点文档](https://code.claude.com/docs/en/checkpointing)，只有在前台运行的
   fork 技能的修改会被恢复；对于其他任何子代理，*“回退不会恢复这些修改。请使用 git 还原它们。”*
   本插件中的每一次写入都发生在五个子代理之一的内部。

因此 `/rewind` 并不是 overlay 工作的安全网。**请使用 git。** 这正是本插件提供
确定性的 Manifest 过期检查和 rm 安全钩子、而不依赖检查点的原因，也是
`safety-rm-check.sh` 选择拒绝而非警告的原因。

### 定期运行 `pkgcheck`

pkgcheck 只有一条路径：**`pkgcheck-watch` 监视器**，在调用
`bentoo` 技能时启动。它扫描缓存的 overlay，在出现新的 ERROR 级别结果时发出通知，
并将每条新结果追加到 `${CLAUDE_PLUGIN_DATA}/pkgcheck.log`。

监视器是实现这一点的原生机制。
[计划任务文档](https://code.claude.com/docs/en/scheduled-tasks) 说得很直白：监视器
*“完全避免了轮询，通常比按固定间隔重新运行提示更节省 token、响应也更快。”*
过去曾有第二个由 cron 驱动的脚本重复执行同样的扫描；它已被删除，而不是任其逐渐偏离。

可通过 `BENTOO_DEV_PKGCHECK_INTERVAL` 调整间隔（单位为秒，默认 300）。

如果你确实需要一个比会话存活更久的计划任务，请注意云端
[Routines](https://code.claude.com/docs/en/routines) **无法**胜任：它们
在全新的克隆中运行，无法访问你本地的 overlay。请使用
**Desktop 计划任务**或 `/loop`，两者都在你的机器上运行。

---

## 关键陷阱（参考）

11 条必须掌握的规则集中在 `references/gotchas.md` 中，并通过
`bentoo-dev:gotchas` 技能提供给子代理（通过 `skills:` frontmatter 预加载，
并设置 `user-invocable: false`）：

1. 覆盖 `src_prepare` 时必须调用 `eapply_user`
2. 可能失败的 shell 命令后加 `|| die`
3. `9999` live ebuild 的 KEYWORDS 留空
4. `S=` 必须与解压出的目录一致
5. 对文件名不具信息量的 tarball，用 `->` 重命名 SRC_URI
6. 二进制包需要 `QA_PREBUILT` + `RESTRICT`
7. 版权声明位于第 1 行，`EAPI=` 为第一个非注释行
8. `thin-manifests` 只包含 DIST 条目
9. `src_prepare` 中的 `default` 会应用 `PATCHES` + `eapply_user`
10. 上游命名不一致时使用 `MY_P` / `MY_PN`
11. `<stabilize-allarches/>` 是用 grep 匹配而不是解析的 — 切勿在 `metadata.xml` 中写入该字面标记，注释中也不行

### 代理强制执行的 overlay 维护规则

有两条规则不属于 ebuild 语法，却会悄无声息地让 overlay 腐化，它们已接入
`ebuild-bumper` 和 `overlay-maintainer`：

- **`pkgdev manifest` 必须带显式目标。** 不带目标时，它会
  重写整个 overlay 的 Manifest。
- **版本升级后按包重新生成 `metadata/md5-cache`**（如果该
  overlay 保留了它）— 否则上一个版本的条目会成为孤立项，
  垃圾随每次升级而增长：
  `egencache --repositories-configuration "$(portageq repos_config /)" --update --repo <repo> <cat>/<pkg>`。
  在不是 Portage 所注册路径的检出副本上，`--repositories-configuration` 是必需的；
  `egencache` 会忽略 `PORTAGE_CONFIGROOT` / `PORTAGE_REPOSITORIES`。

---

## CI / 无头使用

本插件完全兼容 `claude -p` 非交互模式。所有钩子都从 stdin
读取 JSON 负载，手动调用时也能平稳降级。

```bash
# Run QA on every modified ebuild in a PR:
claude -p "/bentoo-dev:bentoo run QA on $(git diff --name-only origin/main | grep '\.ebuild$' | xargs)" \
  --plugin-dir ./bentoo-dev \
  --permission-mode dontAsk \
  --allowedTools "Read Bash Glob Grep Agent" \
  --output-format json | jq -r '.result'

# Validate plugin manifest + components on every PR:
claude plugin validate ./bentoo-dev
```

> **关于 `--bare` 的说明**：该参数（Claude Code v2.1.81+）会完全跳过插件加载
> （连同钩子、技能、MCP、CLAUDE.md）。因此它与通过 `--plugin-dir`
> 调用 `/bentoo-dev:*` 命令不兼容。对于
> 受限的 CI，请使用 `--permission-mode dontAsk`，并如上所示配合显式的
> `--allowedTools` 允许列表。身份验证必须来自
> `ANTHROPIC_API_KEY`。

### 发布

推送标签 `vX.Y.Z` 会触发 `.github/workflows/release.yml`，它会校验
插件并运行 `claude plugin tag .`（v2.1.118+），发布到
marketplace。

---

## 贡献

1. 在 `assets/profiles/<name>.md` 下添加新的 overlay 配置档。
2. 在 `assets/templates/` 下添加新模板。
3. 每当添加新技能或修改触发词时，更新 `evals/evals.json` 和 `evals/trigger-queries.json`。
4. 提升 `.claude-plugin/plugin.json` 中的 `version`，并更新 `CHANGELOG.md`。
5. 新增一条由**人**阅读的消息（权限提示，而不是钩子上下文）时，须在 `scripts/lib/i18n.sh` 的**每一个**目录中为它添加 ID；否则 `bats tests/i18n.bats` 会失败。修改 `README.md` 时，请同步更新译文（`README.<lang>.md`），或在 PR 中说明译文尚未跟上。

---

## 许可证

MIT — 见 `LICENSE`。
